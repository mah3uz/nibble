module Nibble
  module Records
    class NavigationTree < Nibble::ApplicationRecord
      self.table_name = "navigation_trees"
      include Content

      LINK_TYPES = { "entry" => "collections", "term" => "taxonomies" }.freeze

      def self.record_type = "navigation"

      validate { errors.add(:handle, "isn't a navigation in the schema") unless item }
      validate :tree_valid, if: :item

      def item = Nibble.schema.find(:navigation, handle)

      def blueprint_fields = Fields.new([])
      def values = { "tree" => tree.to_a }
      def snapshot = values
      def assign_snapshot(snapshot) = self.tree = snapshot.stringify_keys["tree"].to_a

      def links(nodes = tree.to_a)
        nodes.flat_map { |node| [ node, *links(node["children"].to_a) ] }.select { |node| LINK_TYPES.key?(node["type"]) }
      end

      def relation_rows
        links.each_with_index.map { |node, position| [ "tree", node["type"], node["id"], position ] }
      end

      def event_payload = super.merge("handle" => handle)

      private

      def tree_valid
        return errors.add(:tree, "Menu links must be a list.") unless tree.is_a?(Array)

        check_nodes(tree, "tree", 1)
      end

      def check_nodes(nodes, path, depth)
        max = item["max_depth"]
        nodes.each_with_index do |node, index|
          key = "#{path}.#{index}"
          next errors.add(:tree, "Item #{index + 1} isn't a link.") unless node.is_a?(Hash)

          check_node(node, label(node, index))
          children = node["children"].to_a
          errors.add(:tree, "#{label(node, index)} is nested too deeply. This menu allows #{max} #{max == 1 ? 'level' : 'levels'}.") if max && depth > max
          check_nodes(children, "#{key}.children", depth + 1) if children.any?
        end
      end

      def label(node, index) = node["title"].present? ? "“#{node["title"]}”" : "Link #{index + 1}"

      def check_node(node, key)
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
        else
          errors.add(:tree, "#{key} has a link type this menu doesn't support.")
        end
      end
    end
  end
end
