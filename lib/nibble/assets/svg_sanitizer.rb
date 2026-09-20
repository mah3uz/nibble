module Nibble
  module Assets
    module SvgSanitizer
      REMOVED_ELEMENTS = %w[script foreignObject iframe embed object handler listener].freeze
      UNSAFE_STYLE = /@import|javascript:|expression\s*\(|url\(\s*['"]?\s*(?!#|data:image\/)/i

      module_function

      def call(svg)
        doc = Nokogiri::XML(svg)
        doc.internal_subset&.remove
        doc.xpath("//processing-instruction()").each(&:remove)
        doc.traverse do |node|
          next unless node.element?
          next node.remove if REMOVED_ELEMENTS.include?(node.name)
          next node.remove if node.name == "style" && node.content.match?(UNSAFE_STYLE)

          node.attribute_nodes.each do |attribute|
            name = attribute.name.downcase
            unsafe = name.start_with?("on") || (name == "href" && !attribute.value.strip.start_with?("#", "data:image/")) ||
              (name == "style" && attribute.value.match?(UNSAFE_STYLE))
            attribute.remove if unsafe
          end
        end
        doc.root ? doc.root.to_xml : ""
      end
    end
  end
end
