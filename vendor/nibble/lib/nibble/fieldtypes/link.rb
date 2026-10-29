module Nibble
  module Fieldtypes
    class Link < Fieldtype
      self.categories = %w[relationship]
      self.contract_samples = [ "https://example.com", "entry::1", nil ]
      self.config_field_items = [
        { "display" => "Input Behavior", "fields" => {
          "default_option" => { "type" => "select", "width" => 50 },
          "collections" => { "type" => "list", "default" => [] },
          "taxonomies" => { "type" => "list", "default" => [] }
        } }
      ]

      def preload
        type, id = LinkTypes.parse(field&.value)
        item = type && LinkTypes.find(type).resolver.resolve(id)
        {
          "initial_url" => type ? nil : field&.value,
          "initial_option" => type || (field&.value.present? ? "url" : config("default_option")),
          "selected" => id,
          "item" => item && { "id" => id, "title" => item[:title], "url" => item[:url] },
          "types" => LinkTypes.all.to_h { |link_type| [ link_type.handle, { "title" => type_title(link_type) } ] }
        }
      end

      def type_title(link_type)
        return link_type.title unless link_type.handle == "term"

        handles = Array(config("taxonomies")).presence || Nibble.schema.taxonomies.map(&:handle)
        titles = handles.filter_map { |handle| Nibble.schema.taxonomy(handle)&.[]("title")&.singularize }
        titles.any? ? titles.to_sentence(two_words_connector: " or ", last_word_connector: " or ") : link_type.title
      end

      def pre_process_index(value)
        url = augment(value)&.dig("url") or return nil
        { "type" => LinkTypes.parse(value)&.first || "url", "url" => url }
      end

      def augment(value)
        return nil if value.blank?

        type, id = LinkTypes.parse(value)
        return { "type" => "url", "url" => value } unless type

        target = LinkTypes.find(type).resolver.resolve(id)
        target && { "type" => type, "id" => id, "url" => target[:url], "title" => target[:title] }
      end

      def rules = %w[string safe_link]

      def import(value, ctx = nil)
        return value unless ctx && value.is_a?(String) && value.include?(LinkTypes::SEPARATOR)

        type, key = value.split(LinkTypes::SEPARATOR, 2)
        "#{type}#{LinkTypes::SEPARATOR}#{ctx.resolve(type, key)}"
      end

      def export(value, ctx = nil)
        return value unless ctx && value.is_a?(String) && value.include?(LinkTypes::SEPARATOR)

        type, id = value.split(LinkTypes::SEPARATOR, 2)
        key = ctx.resolve(type, id) or return nil
        "#{type}#{LinkTypes::SEPARATOR}#{key}"
      end

      def relations(value)
        type, id = LinkTypes.parse(value)
        type ? [ [ type, id ] ] : []
      end

      def ts_type = "{ type: string; url: string; id?: string; title?: string } | null"
    end
  end
end
