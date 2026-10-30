module Nibble
  module Records
    class NavigationTree < Nibble::ApplicationRecord
      self.table_name = "navigation_trees"
      include Content

      LINK_TYPES = { "entry" => "collections", "term" => "taxonomies" }.freeze
      RECORD_LINKS = %w[entry term asset].freeze

      def self.record_type = "navigation"
      def self.kind(node) = node["kind"].presence || "link"

      validate { errors.add(:handle, "isn't a navigation in the schema") unless item }
      validate :tree_valid, if: :item
      before_save :process_item_fields, if: -> { item && item_fields.any? }

      def item = Nibble.schema.find(:navigation, handle)

      def blueprint_fields = Fields.new([])
      def item_fields = Fields.new(item&.[]("item_fields"), schema: Nibble.schema, source: item&.path, key: "item_fields")
      def values = { "tree" => tree.to_a }
      def snapshot = values
      def assign_snapshot(snapshot) = self.tree = snapshot.stringify_keys["tree"].to_a

      def links(nodes = tree.to_a)
        flatten(nodes).select { |node| RECORD_LINKS.include?(node["type"]) }
      end

      def relation_rows
        fields = item_fields
        targets = links.map { |node| [ node["type"], node["id"] ] }
        if fields.any?
          targets += flatten(tree.to_a).flat_map do |node|
            fields.add_values(node["fields"].to_h.stringify_keys).flat_map { |field| field.fieldtype.relations(field.value) }
          end
        end
        targets.each_with_index.map { |(type, id), position| [ "tree", type, id, position ] }
      end

      def event_payload = super.merge("handle" => handle)

      def processed_tree(nodes) = item_fields.any? ? processed(nodes, item_fields) : nodes

      private

      def flatten(nodes) = nodes.select { |node| node.is_a?(Hash) }.flat_map { |node| [ node, *flatten(node["children"].to_a) ] }

      def tree_valid
        return errors.add(:tree, "Menu links must be a list.") unless tree.is_a?(Array)

        check_nodes(tree, "tree", 1, item_fields)
      end

      def check_nodes(nodes, path, depth, fields)
        max = item["max_depth"]
        nodes.each_with_index do |node, index|
          key = "#{path}.#{index}"
          next errors.add(:tree, "Item #{index + 1} isn't a link.") unless node.is_a?(Hash)

          check_node(node, label(node, index))
          check_fields(node, label(node, index), fields)
          children = node["children"].to_a
          errors.add(:tree, "#{label(node, index)} is nested too deeply. This menu allows #{max} #{max == 1 ? 'level' : 'levels'}.") if max && depth > max
          check_nodes(children, "#{key}.children", depth + 1, fields) if children.any?
        end
      end

      def label(node, index) = node["title"].present? ? "“#{node["title"]}”" : "Link #{index + 1}"

      def check_node(node, key)
        flags = %w[new_tab hidden].reject { |flag| [ nil, true, false ].include?(node[flag]) }
        errors.add(:tree, "#{key} has #{flags.join(' and ')} set to something other than true or false.") if flags.any?
        case self.class.kind(node)
        when "link" then check_link(node, key)
        when "heading"
          return errors.add(:tree, "#{key} is a heading, which this menu doesn't allow.") unless item["headings"] == true

          errors.add(:tree, "#{key} is a heading, which needs a title.") if node["title"].blank?
          errors.add(:tree, "#{key} is a heading, so it can't link anywhere.") if node.values_at("type", "url", "id", "ref").any?(&:present?)
        else
          errors.add(:tree, "#{key} is a kind of item this menu doesn't support.")
        end
      end

      def check_link(node, key)
        case node["type"]
        when "url"
          errors.add(:tree, "#{key} needs a title and a web address.") if node["url"].blank? || node["title"].blank?
          errors.add(:tree, "#{key} must link to a web page, an email address or a phone number.") if node["url"].present? && !SafeUrl.safe?(node["url"])
        when *LINK_TYPES.keys
          allowed = Array(item[LINK_TYPES[node["type"]]])
          target = Records.model(node["type"]).find_by(id: node["id"], deleted_at: nil)
          scope = target && (node["type"] == "entry" ? target.collection : target.taxonomy)
          errors.add(:tree, "#{key} links to #{node['type'] == 'entry' ? 'a page' : 'a term'} that's been deleted. Choose another.") unless target
          errors.add(:tree, "#{key} links to #{scope.to_s.humanize}, which this menu can't link to.") if target && !allowed.include?(scope)
        when "global" then check_global(node, key)
        when "asset" then check_asset(node, key)
        else
          errors.add(:tree, "#{key} has a link type this menu doesn't support.")
        end
      end

      def check_global(node, key)
        handle, = GlobalLinks.parse(node["ref"])
        allowed = item["globals"]
        return errors.add(:tree, "#{key} links to a site setting, which this menu can't link to.") unless allowed == true || (allowed.is_a?(Array) && allowed.include?(handle))

        errors.add(:tree, "#{key} needs a title.") if node["title"].blank?
        errors.add(:tree, "#{key} links to a site setting that doesn't hold an address. Choose another.") unless GlobalLinks.field(node["ref"])
      end

      def check_asset(node, key)
        return errors.add(:tree, "#{key} links to a file, which this menu can't link to.") unless item["assets"] == true

        errors.add(:tree, "#{key} links to a file that's been deleted. Choose another.") unless Asset.kept.exists?(id: node["id"])
      end

      def check_fields(node, key, fields)
        values = node["fields"]
        return errors.add(:tree, "#{key} has fields that aren't a set of values.") unless values.nil? || values.is_a?(Hash)
        return if fields.empty?

        Validator.new(fields, locale:).validate(values.to_h).errors.each_value do |messages|
          messages.each { |message| errors.add(:tree, "#{key}: #{message}") }
        end
      end

      def process_item_fields = self.tree = processed_tree(tree)

      def processed(nodes, fields)
        nodes.map do |node|
          next node unless node.is_a?(Hash)

          node = node.merge("children" => processed(node["children"], fields)) if node["children"].is_a?(Array)
          next node unless node["fields"].is_a?(Hash)

          values = node["fields"].to_h.stringify_keys
          node.merge("fields" => values.except(*fields.handles).merge(fields.add_values(values.slice(*fields.handles)).process.values.compact))
        end
      end
    end
  end
end
