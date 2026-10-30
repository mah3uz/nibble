module Nibble
  module Packages
    class Exporter
      COLUMN_KEYS = %w[blueprint status published_at unpublish_at template position].freeze
      ASSET_KEYS = %w[title alt caption credit focal_x focal_y focal_zoom tags].freeze

      def initialize(root, collections: nil, taxonomies: nil, locales: nil, status: nil)
        @root = Pathname(root)
        @collections = collections.presence
        @taxonomies = taxonomies.presence
        @locales = locales.presence
        @status = status.presence
        @keys = Keys.new
        @context = ExportContext.new(@keys)
      end

      def call
        @root.mkpath
        (entries + terms + globals + navigation + redirects + assets).compact.sort
      end

      private

      def entries
        scope = Records::Entry.kept.order(:collection, :locale, :id)
        scope = scope.where(collection: @collections) if @collections
        scope = scope.where(locale: @locales) if @locales
        scope = scope.where(status: @status == "published" ? %w[published scheduled] : @status) if @status
        scope.map do |entry|
          handle, *slugs = @keys.entry_key(entry.id).split("/")
          write("collections/#{handle}/#{entry.locale}/#{slugs.join('/')}", entry_data(entry))
        end
      end

      def terms
        scope = Records::Term.kept.order(:taxonomy, :locale, :id)
        scope = scope.where(taxonomy: @taxonomies) if @taxonomies
        scope = scope.where(locale: @locales) if @locales
        scope.map { |term| write("taxonomies/#{term.taxonomy}/#{term.locale}/#{term.slug}", { "blueprint" => term.blueprint }.merge(values(term))) }
      end

      def globals
        scope = Records::GlobalSet.order(:handle, :locale)
        scope = scope.where(locale: @locales) if @locales
        scope.filter_map do |global|
          next unless global.item

          write("globals/#{global.handle}/#{global.locale}", values(global))
        end
      end

      def navigation
        scope = Records::NavigationTree.order(:handle, :locale)
        scope = scope.where(locale: @locales) if @locales
        scope.map { |menu| write("navigation/#{menu.handle}/#{menu.locale}", { "tree" => tree(menu.tree.to_a, menu.item_fields) }) }
      end

      def redirects
        rows = Records::Redirect.order(:from).map { |row| { "from" => row.from, "to" => row.to, "status" => row.status } }
        rows.any? ? [ write("redirects", rows) ] : []
      end

      def assets
        rows = Records::Asset.kept.order(:folder, :filename).map do |asset|
          { "path" => @keys.asset_key(asset.id), "mime" => asset.mime }
            .merge(ASSET_KEYS.filter_map { |key| [ key, asset.public_send(key) ] if asset.public_send(key).present? }.to_h)
        end
        rows.any? ? [ write("assets", rows) ] : []
      end

      def entry_data(entry)
        columns = {
          "blueprint" => entry.blueprint, "status" => %w[published scheduled].include?(entry.status) ? "published" : "draft",
          "published_at" => entry.published_at&.utc&.iso8601, "unpublish_at" => entry.unpublish_at&.utc&.iso8601,
          "template" => entry.template, "position" => entry.position
        }.compact
        columns.merge(values(entry))
      end

      def values(record) = exported(record.blueprint_fields, record.values)

      def exported(fields, stored)
        fields.all.filter_map do |handle, field|
          next unless stored.key?(handle)

          exported = field.fieldtype.export(stored[handle], @context)
          [ handle, exported ] unless exported.nil? || exported == []
        end.to_h
      end

      def tree(nodes, fields)
        nodes.filter_map do |node|
          next unless node.is_a?(Hash)

          link = target(node) or next
          link["title"] = node["title"] if node["title"].present?
          link.merge!(node.slice(*NODE_KEYS).compact)
          values = exported(fields, node["fields"].stringify_keys) if node["fields"].is_a?(Hash)
          link["fields"] = values if values.present?
          if node["query"].is_a?(Hash)
            link["query"] = query(node["query"].stringify_keys) or next
          end
          children = tree(node["children"].to_a, fields)
          children.any? ? link.merge("children" => children) : link
        end
      end

      def target(node)
        case node["type"]
        when *Records::NavigationTree::RECORD_LINKS
          key = @keys.key(node["type"], node["id"])
          { node["type"] => key } if key
        when "global" then { "ref" => node["ref"] } if node["ref"].present?
        else
          if node["url"] then { "url" => node["url"] }
          elsif Records::NavigationTree.kind(node) != "link" then {}
          end
        end
      end

      def query(query)
        if query["parent"].present?
          query = query.merge("parent" => @keys.entry_key(query["parent"]))
          return nil unless query["parent"]
        end
        term = query["term"]
        return query unless term.is_a?(Hash) && term["id"].present?

        key = @keys.term_key(term["id"]) or return nil
        query.merge("term" => term.merge("id" => key))
      end

      def write(relative, data)
        path = @root.join("#{relative}.yml")
        path.dirname.mkpath
        path.write(data.to_yaml(line_width: -1))
        "#{relative}.yml"
      end
    end
  end
end
