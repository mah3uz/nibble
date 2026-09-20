module Nibble
  module Packages
    class Exporter
      COLUMN_KEYS = %w[blueprint status published_at unpublish_at template].freeze
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
        scope.map { |menu| write("navigation/#{menu.handle}/#{menu.locale}", { "tree" => tree(menu.tree.to_a) }) }
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
          "template" => entry.template
        }.compact
        columns.merge(values(entry))
      end

      def values(record)
        fields = record.blueprint_fields.all
        stored = record.values
        fields.filter_map do |handle, field|
          next unless stored.key?(handle)

          exported = field.fieldtype.export(stored[handle], @context)
          [ handle, exported ] unless exported.nil? || exported == []
        end.to_h
      end

      def tree(nodes)
        nodes.filter_map do |node|
          link = case node["type"]
          when "entry", "term" then { node["type"] => @keys.key(node["type"], node["id"]) }
          else { "url" => node["url"] }
          end
          next if link.values.first.nil?

          link["title"] = node["title"] if node["title"].present?
          children = tree(node["children"].to_a)
          children.any? ? link.merge("children" => children) : link
        end
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
