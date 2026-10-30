module Nibble
  module Options
    SOURCE = /\A(entries|terms):/

    def self.for(field, fields = nil)
      raw = field&.get("options")
      content?(raw) ? Content.new(field, fields) : Static.new(raw)
    end

    def self.content?(raw) = raw.is_a?(Hash) && raw["from"].is_a?(String) && raw["from"].match?(SOURCE)

    class Static
      def initialize(raw) = @raw = raw || []

      def content? = false

      def options(locale = nil)
        pairs = case @raw
        when Hash then @raw.map { |value, label| [ value, label ] }
        else
          @raw.map do |item|
            item.is_a?(Hash) ? [ item["key"] || item["value"], item["label"] || item["value"] ] : [ item, item ]
          end
        end
        pairs.map { |value, label| { "value" => value, "label" => label.nil? ? value : Localized.resolve(label, locale) } }
      end

      def localized_labels
        return @raw.to_a if @raw.is_a?(Hash)

        Array(@raw).filter_map { |item| [ item["key"] || item["value"], item["label"] ] if item.is_a?(Hash) }
      end
    end
  end
end
