module Nibble
  module Records
    class NavigationTree < Nibble::ApplicationRecord
      self.table_name = "navigation_trees"
      include Content

      LINK_TYPES = { "entry" => "collections", "term" => "taxonomies" }.freeze
      RECORD_LINKS = %w[entry term asset].freeze

      def self.record_type = "navigation"
      def self.kind(node) = node["kind"].presence || "link"
      def self.linked?(node) = node.values_at("type", "url", "id", "ref").any?(&:present?)
      def self.time(value) = Time.zone.iso8601(value.to_s)

      # An unreadable date hides the item: it was meant to show only for a while.
      def self.shown?(node, now)
        from, till = node.values_at("show_from", "show_until").map { |value| value.presence && time(value) }
        (from.nil? || from <= now) && (till.nil? || now < till)
      rescue ArgumentError
        false
      end

      validate { errors.add(:handle, "isn't a navigation in the schema") unless item }
      validate :tree_valid, if: :item
      before_save :process_item_fields, if: -> { item && (item_fields.any? || menu.kinds.any?) }

      def item = Nibble.schema.find(:navigation, handle)
      def menu = MenuSchema.new(item)

      def blueprint_fields = Fields.new([])
      def item_fields = Fields.new(item&.[]("item_fields"), schema: Nibble.schema, source: item&.path, key: "item_fields")
      def values = { "tree" => tree.to_a }
      def snapshot = values
      def assign_snapshot(snapshot) = self.tree = snapshot.stringify_keys["tree"].to_a

      def links(nodes = tree.to_a)
        flatten(nodes).select { |node| RECORD_LINKS.include?(node["type"]) }
      end

      def show_dates
        flatten(tree.to_a).flat_map { |node| node.values_at("show_from", "show_until") }.compact_blank.map { |value| self.class.time(value) }.uniq
      end

      def relation_rows
        menu = self.menu if item
        targets = links.map { |node| [ node["type"], node["id"] ] }
        if menu && (menu.item_fields.any? || menu.kinds.any?)
          targets += flatten(tree.to_a).flat_map do |node|
            fields = menu.fields_for(self.class.kind(node))
            fields.add_values(node["fields"].to_h.stringify_keys).flat_map { |field| field.fieldtype.relations(field.value) }
          end
        end
        targets.each_with_index.map { |(type, id), position| [ "tree", type, id, position ] }
      end

      def event_payload = super.merge("handle" => handle)

      def processed_tree(nodes) = processed(nodes, menu)

      private

      def flatten(nodes) = nodes.select { |node| node.is_a?(Hash) }.flat_map { |node| [ node, *flatten(node["children"].to_a) ] }

      def tree_valid
        return errors.add(:tree, "Menu links must be a list.") unless tree.is_a?(Array)

        check_nodes(tree, "tree", 1, menu)
      end

      def check_nodes(nodes, path, depth, menu)
        max = item["max_depth"]
        nodes.each_with_index do |node, index|
          key = @checking = "#{path}.#{index}"
          next flag("Item #{index + 1} isn't a link.") unless node.is_a?(Hash)

          check_node(node, label(node, index), menu)
          check_fields(node, label(node, index), menu.fields_for(self.class.kind(node)))
          check_dates(node, label(node, index))
          children = node["children"].to_a
          flag("#{label(node, index)} is nested too deeply. This menu allows #{max} #{max == 1 ? 'level' : 'levels'}.") if max && depth > max
          check_nodes(children, "#{key}.children", depth + 1, menu) if children.any?
        end
      end

      def label(node, index) = node["title"].present? ? "“#{node["title"]}”" : "Link #{index + 1}"

      def check_node(node, key, menu)
        flags = %w[new_tab hidden].reject { |flag| [ nil, true, false ].include?(node[flag]) }
        flag("#{key} has #{flags.join(' and ')} set to something other than true or false.") if flags.any?
        case (kind = self.class.kind(node))
        when "link" then check_link(node, key)
        when "heading"
          return flag("#{key} is a heading, which this menu doesn't allow.") unless item["headings"] == true

          flag("#{key} is a heading, which needs a title.") if node["title"].blank?
          flag("#{key} is a heading, so it can't link anywhere.") if linked?(node)
        when "query" then check_query(node, key, menu)
        else
          custom = menu.kind(kind) or return flag("#{key} is a kind of item this menu doesn't support.")

          check_custom(node, key, custom)
        end
      end

      def linked?(node) = self.class.linked?(node)

      def check_custom(node, key, kind)
        case kind.link
        when "required" then linked?(node) ? check_link(node, key) : flag("#{key} is a #{kind.display}, which needs a link.")
        when "none" then flag("#{key} is a #{kind.display}, so it can't link anywhere.") if linked?(node)
        else check_link(node, key) if linked?(node)
        end
        flag("#{key} is a #{kind.display}, which can't have items under it.") if !kind.children && node["children"].to_a.any?
      end

      def check_query(node, key, menu)
        return flag("#{key} lists pages, which this menu doesn't allow.") if menu.queries.empty?

        flag("#{key} lists pages, which needs a title.") if node["title"].blank?
        flag("#{key} lists pages, so it can't link anywhere.") if linked?(node)
        flag("#{key} lists pages, so its items come from them rather than being added.") if node["children"].to_a.any?
        MenuQuery.new(node["query"]).problems(menu, locale).each { |problem| flag("#{key} #{problem}.") }
      end

      def check_dates(node, key)
        from, till = node.values_at("show_from", "show_until").map { |value| value.presence && self.class.time(value) }
        flag("#{key} stops showing before it starts. Choose a show until date after its show from date.") if from && till && from >= till
      rescue ArgumentError
        flag("#{key} has a show date that isn't a date and time, such as 2026-11-01T09:00:00+10:00.")
      end

      def check_link(node, key)
        case node["type"]
        when "url"
          flag("#{key} needs a title and a web address.") if node["url"].blank? || node["title"].blank?
          flag("#{key} must link to a web page, an email address or a phone number.") if node["url"].present? && !SafeUrl.safe?(node["url"])
        when *LINK_TYPES.keys
          allowed = Array(item[LINK_TYPES[node["type"]]])
          target = Records.model(node["type"]).find_by(id: node["id"], deleted_at: nil)
          scope = target && (node["type"] == "entry" ? target.collection : target.taxonomy)
          flag("#{key} links to #{node['type'] == 'entry' ? 'a page' : 'a term'} that's been deleted. Choose another.") unless target
          flag("#{key} links to #{scope.to_s.humanize}, which this menu can't link to.") if target && !allowed.include?(scope)
        when "global" then check_global(node, key)
        when "asset" then check_asset(node, key)
        else
          flag("#{key} has a link type this menu doesn't support.")
        end
      end

      def check_global(node, key)
        handle, = GlobalLinks.parse(node["ref"])
        allowed = item["globals"]
        return flag("#{key} links to a site setting, which this menu can't link to.") unless allowed == true || (allowed.is_a?(Array) && allowed.include?(handle))

        flag("#{key} needs a title.") if node["title"].blank?
        flag("#{key} links to a site setting that doesn't hold an address. Choose another.") unless GlobalLinks.field(node["ref"])
      end

      def check_asset(node, key)
        return flag("#{key} links to a file, which this menu can't link to.") unless item["assets"] == true

        flag("#{key} links to a file that's been deleted. Choose another.") unless Asset.kept.exists?(id: node["id"])
      end

      def check_fields(node, key, fields)
        values = node["fields"]
        return flag("#{key} has fields that aren't a set of values.") unless values.nil? || values.is_a?(Hash)
        return if fields.empty?

        Validator.new(fields, locale:).validate(values.to_h).errors.each do |field, messages|
          messages.each { |message| flag("#{key}: #{message}", "#{@checking}.fields.#{field}") }
        end
      end

      def flag(message, path = @checking) = errors.add(:tree, message, path:)

      def process_item_fields = self.tree = processed_tree(tree)

      def processed(nodes, menu)
        nodes.map do |node|
          next node unless node.is_a?(Hash)

          node = node.merge("children" => processed(node["children"], menu)) if node["children"].is_a?(Array)
          next node unless node["fields"].is_a?(Hash)

          fields = menu.fields_for(self.class.kind(node))
          values = node["fields"].to_h.stringify_keys
          node.merge("fields" => values.except(*fields.handles).merge(fields.add_values(values.slice(*fields.handles)).process.values.compact))
        end
      end
    end
  end
end
