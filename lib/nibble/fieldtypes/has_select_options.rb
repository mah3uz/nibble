module Nibble
  module Fieldtypes
    module HasSelectOptions
      def multiple? = config("multiple") == true

      def options
        raw = config("options") || []
        pairs = case raw
        when Hash then raw.map { |value, label| [ value, label ] }
        else
          raw.map do |item|
            item.is_a?(Hash) ? [ item["key"] || item["value"], item["label"] || item["value"] ] : [ item, item ]
          end
        end
        pairs.map { |value, label| { "value" => value, "label" => label.nil? ? value : label } }
      end

      def preload = { "options" => options }

      def pre_process(value)
        return [] if value.nil? && multiple?

        values = Array.wrap(value.nil? ? [ nil ] : value).map { |item| cast_booleans? ? from_boolean(item) : item }
        multiple? ? values : values.first
      end

      def process(value)
        values = Array.wrap(value).map { |item| cast_booleans? ? to_boolean(item) : item }
        multiple? ? values : values.first
      end

      def pre_process_index(value)
        values = pre_process(value)
        Array.wrap(values.nil? ? [ nil ] : values).map { |item| label_for(item) }
      end

      def augment(value)
        return (value || []).map { |item| labeled(item) } if multiple?
        raise Error, "#{field&.handle} holds several values but isn't a multiple select" if value.is_a?(Array)

        labeled(value)
      end

      def rules
        return [] if config("taggable") == true || options.empty?

        [ "in:#{options.map { |option| option['value'].to_s }.join(',')}" ]
      end

      def search_text(value) = Array.wrap(augment(value)).filter_map { |item| item["label"]&.to_s }.join(" ").presence

      def ts_type = multiple? ? "{ value: string; label: string }[]" : "{ value: string | null; label: string | null }"

      private

      def cast_booleans? = config("cast_booleans") == true

      def labeled(value)
        value = normalize(value)
        { "value" => value, "label" => label_for(value) }
      end

      def label_for(actual)
        lookup = cast_booleans? ? from_boolean(actual) : actual
        option = options.find { |candidate| candidate["value"] == lookup }
        option ? option["label"] : actual
      end

      def normalize(value)
        return value unless value.is_a?(String) && value.match?(/\A-?\d+(\.\d+)?\z/)

        value.include?(".") ? value : value.to_i
      end

      def to_boolean(value) = { "true" => true, "false" => false }.fetch(value, value)
      def from_boolean(value) = { true => "true", false => "false" }.fetch(value, value)
    end
  end
end
