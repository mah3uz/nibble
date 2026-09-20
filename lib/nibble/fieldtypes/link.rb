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
          "types" => LinkTypes.all.to_h { |link_type| [ link_type.handle, { "title" => link_type.title } ] }
        }
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

      def rules = [ "string" ]

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
