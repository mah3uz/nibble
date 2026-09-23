module Nibble
  module Fieldtypes
    class Text < Fieldtype
      INPUT_TYPES = %w[color date email hidden month number password tel text time url week].freeze

      self.categories = %w[text]
      self.contract_samples = [ "Hello", nil ]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Input Behavior", "fields" => {
          "input_type" => { "type" => "select", "default" => "text", "options" => INPUT_TYPES, "width" => 50 },
          "character_limit" => { "type" => "integer", "width" => 50 },
          "autocomplete" => { "type" => "text", "width" => 50 }
        } },
        { "display" => "Appearance", "fields" => {
          "placeholder" => { "type" => "text" },
          "prepend" => { "type" => "text", "width" => 50 },
          "append" => { "type" => "text", "width" => 50 }
        } }
      ]

      def process(value)
        return value unless !value.nil? && config("input_type") == "number"

        value.to_s.include?(".") ? value.to_f : value.to_i
      end

      def pre_process_index(value)
        value.nil? ? nil : "#{config('prepend')}#{value}#{config('append')}"
      end

      def rules
        [
          *({ "email" => "email", "url" => "url", "number" => "numeric" }[config("input_type")]),
          *("max:#{config('character_limit')}" if config("character_limit").to_i.positive?)
        ]
      end

      def search_text(value) = value.is_a?(String) ? value : nil
      def ts_type = config("input_type") == "number" ? "number | null" : "string | null"
    end
  end
end
