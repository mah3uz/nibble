module Nibble
  module Fieldtypes
    class RichText < Fieldtype
      include HasSets

      INLINE_NODES = %w[text hardBreak].freeze
      DEFAULT_BUTTONS = %w[h2 h3 bold italic unorderedlist orderedlist removeformat quote anchor image table].freeze

      self.categories = %w[text structured]
      self.contract_samples = [ [ { "type" => "paragraph", "content" => [ { "type" => "text", "text" => "Hi" } ] } ], nil ]
      self.keywords = %w[rich text editor wysiwyg html]
      self.config_field_items = [
        { "display" => "Editor Settings", "fields" => {
          "buttons" => { "type" => "list", "default" => DEFAULT_BUTTONS },
          "toolbar_mode" => { "type" => "select", "default" => "fixed", "options" => %w[fixed floating] },
          "smart_typography" => { "type" => "toggle", "default" => false, "width" => 50 },
          "enable_input_rules" => { "type" => "toggle", "default" => true, "width" => 50 },
          "enable_paste_rules" => { "type" => "toggle", "default" => true, "width" => 50 },
          "placeholder" => { "type" => "text", "width" => 50 },
          "character_limit" => { "type" => "integer", "width" => 50 },
          "reading_time" => { "type" => "toggle", "default" => false, "width" => 50 },
          "word_count" => { "type" => "toggle", "default" => false, "width" => 50 },
          "fullscreen" => { "type" => "toggle", "default" => true, "width" => 50 },
          "image_preset" => { "type" => "text", "default" => "content", "width" => 50 }
        } },
        { "display" => "Links", "fields" => {
          "link_noopener" => { "type" => "toggle", "default" => false, "width" => 33 },
          "link_noreferrer" => { "type" => "toggle", "default" => false, "width" => 33 },
          "target_blank" => { "type" => "toggle", "default" => false, "width" => 33 },
          "link_collections" => { "type" => "list", "default" => [] }
        } },
        { "display" => "Sets", "fields" => {
          "sets" => { "type" => "list" },
          "always_show_set_button" => { "type" => "toggle", "default" => false, "width" => 50 },
          "collapse" => { "type" => "toggle", "default" => false, "width" => 50 },
          "previews" => { "type" => "toggle", "default" => true, "width" => 50 }
        } },
        { "display" => "Data & Format", "fields" => {
          "remove_empty_nodes" => { "type" => "select", "default" => false, "options" => [ false, true, "trim" ] },
          "inline" => { "type" => "toggle", "default" => false, "width" => 50 },
          "inline_hard_breaks" => { "type" => "toggle", "default" => false, "width" => 50, "if" => { "inline" => true } }
        } }
      ]

      def pre_process(value)
        nodes = to_nodes(value)
        return [] if nodes.empty?

        nodes = if inline?
          wrap_inline(INLINE_NODES.include?(nodes.first["type"]) ? nodes : unwrap_inline(nodes))
        else
          INLINE_NODES.include?(nodes.first["type"]) ? wrap_inline(nodes) : nodes
        end

        nodes = refresh_images(nodes)
        nodes.each_with_index.map do |node, index|
          next node unless set_node?(node)

          values = node.dig("attrs", "values").to_h
          type = values["type"]
          processed = set_fields(type, index).add_values(values).pre_process.values
          { "type" => "set", "attrs" => { "id" => node.dig("attrs", "id") || HasSets.generate_id,
                                          "enabled" => node.dig("attrs", "enabled") != false,
                                          "values" => values.except("enabled").merge(processed).merge("type" => type) } }
        end
      end

      def preload = sets? ? set_preload(set_rows(to_nodes(field&.value))) : nil

      def pre_process_validatable(value)
        to_nodes(value).each_with_index.map do |node, index|
          next node unless set_node?(node)

          values = node.dig("attrs", "values").to_h
          node.deep_merge("attrs" => { "values" => set_fields(values["type"], index).add_values(values).pre_process_validatable.values })
        end
      end

      def extra_rules(root_values: nil, prefix: "", replacements: {})
        set_extra_rules(set_rows(to_nodes(field&.value)), root_values:, prefix:, replacements:)
      end

      def process(value)
        nodes = remove_empty_nodes(to_nodes(value))
        nodes = unwrap_inline(nodes) if inline?
        structure = nodes.each_with_index.map do |node, index|
          next node unless set_node?(node)

          values = node.dig("attrs", "values").to_h
          processed = set_fields(values["type"], index).add_values(values).process.values
          attrs = node["attrs"].except("enabled").merge("values" => values.merge(processed).compact)
          attrs["enabled"] = false if node.dig("attrs", "enabled") == false
          node.merge("attrs" => attrs)
        end
        structure.empty? || structure == [ { "type" => "paragraph" } ] ? nil : structure
      end

      def pre_process_index(value) = plain_text(to_nodes(value)).truncate(100).presence

      def augment(value, shallow: false)
        nodes = to_nodes(value)
        return (sets? ? [] : nil) if nodes.empty?
        return render(nodes) unless sets?

        blocks = []
        chunk = []
        flush = lambda do
          blocks << { "type" => "text", "text" => render(chunk) } if chunk.any?
          chunk = []
        end
        nodes.each_with_index do |node, index|
          if set_node?(node)
            flush.call
            next if node.dig("attrs", "enabled") == false

            values = node.dig("attrs", "values").to_h
            blocks << augment_set(values["type"], node.dig("attrs", "id"), values.except("type"), index, shallow:)
          else
            chunk << node
          end
        end
        flush.call
        blocks
      end

      def shallow_augment(value) = augment(value, shallow: true)

      def import(value, ctx = nil) = transfer(value, ctx, :import)
      def export(value, ctx = nil) = transfer(value, ctx, :export)

      def transfer(value, ctx, direction)
        return value unless ctx && value.present?

        nodes = to_nodes(value)
        if sets?
          _, transferred = transfer_sets(value, ctx, direction)
          nodes = nodes.each_with_index.map do |node, index|
            transferred.key?(index) ? node.deep_merge("attrs" => { "values" => transferred[index] }) : node
          end
        end
        move_images(nodes, ctx)
      end

      def relations(value) = super + image_assets(value).map { |id| [ "asset", id ] }
      def dependencies(value) = super + image_assets(value).map { |id| "asset:#{id}" }

      def search_text(value) = [ plain_text(to_nodes(value)).presence, (set_search_text(value) if sets?) ].compact.join(" ").presence

      def ts_type = sets? ? "Array<{ type: 'text'; text: string } | ({ id: string; type: string } & Record<string, unknown>)>" : "string | null"

      private

      # The editor draws an image from its src, which goes stale when the asset changes or content moves between
      # sites, so every load takes the current URL and size from the asset itself.
      def refresh_images(nodes)
        ids = find_images(nodes).filter_map { |node| node.dig("attrs", "asset").presence&.to_s }.uniq
        return nodes if ids.empty?

        found = Resolvers.find("asset").find(ids).index_by { |summary| summary["id"] }
        swap_images(nodes, found)
      end

      def swap_images(nodes, found)
        nodes.map do |node|
          next node unless node.is_a?(Hash)

          node = node.merge("content" => swap_images(node["content"], found)) if node["content"].is_a?(Array)
          asset = node["type"] == "image" && found[node.dig("attrs", "asset").to_s]
          asset ? node.deep_merge("attrs" => asset.slice("width", "height").merge("src" => asset["url"])) : node
        end
      end

      def move_images(nodes, ctx)
        nodes.map do |node|
          next node unless node.is_a?(Hash)

          node = node.merge("content" => move_images(node["content"], ctx)) if node["content"].is_a?(Array)
          asset = node.dig("attrs", "asset")
          node["type"] == "image" && asset.present? ? node.deep_merge("attrs" => { "asset" => ctx.resolve("asset", asset) }) : node
        end
      end

      def row_path(index) = "#{index}.attrs.values"

      def set_value_rows(value) = set_rows(to_nodes(value))

      def inline? = config("inline") == true

      def set_node?(node) = node.is_a?(Hash) && node["type"] == "set"

      def set_rows(nodes)
        nodes.each_with_index.filter_map do |node, index|
          next unless set_node?(node)

          values = node.dig("attrs", "values").to_h
          { id: node.dig("attrs", "id"), type: values["type"], values:, index: }
        end
      end

      def to_nodes(value)
        case value
        when nil, "" then []
        when String then [ { "type" => "paragraph", "content" => [ { "type" => "text", "text" => value } ] } ]
        when Hash then value["type"] == "doc" ? Array(value["content"]) : [ value ]
        else Array(value).select { |node| node.is_a?(Hash) && node.key?("type") }.map(&:deep_stringify_keys)
        end
      end

      def wrap_inline(nodes) = [ { "type" => "paragraph", "content" => nodes } ]
      def unwrap_inline(nodes) = Array(nodes.first&.dig("content"))

      def remove_empty_nodes(nodes)
        empty = ->(node) { node.is_a?(Hash) && %w[heading paragraph].include?(node["type"]) && !node.key?("content") }
        case config("remove_empty_nodes")
        when true then nodes.reject(&empty)
        when "trim"
          nodes = nodes.drop_while(&empty)
          nodes.reverse.drop_while(&empty).reverse
        else nodes
        end
      end

      def render(nodes) = ::RichText::Renderer.call({ "type" => "doc", "content" => nodes }, image_preset: config("image_preset"))

      def image_assets(value) = find_images(to_nodes(value)).filter_map { |node| node.dig("attrs", "asset").presence&.to_s }.uniq

      def find_images(nodes)
        nodes.flat_map { |node| node.is_a?(Hash) ? (node["type"] == "image" ? [ node ] : find_images(Array(node["content"]))) : [] }
      end

      def plain_text(nodes)
        nodes.map { |node| node["type"] == "text" ? node["text"].to_s : plain_text(Array(node["content"])) }.join(" ").squish
      end
    end
  end
end
