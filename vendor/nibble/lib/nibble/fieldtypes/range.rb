module Nibble
  module Fieldtypes
    class Range < Fieldtype
      self.categories = %w[number controls]
      self.keywords = %w[slider]
      self.contract_samples = [ 0, 40, nil ]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Appearance", "fields" => {
          "prepend" => { "type" => "text", "width" => 50 },
          "append" => { "type" => "text", "width" => 50 }
        } },
        { "display" => "Data & Format", "fields" => {
          "min" => { "type" => "text", "input_type" => "number", "default" => 0, "width" => 33 },
          "max" => { "type" => "text", "input_type" => "number", "default" => 100, "width" => 33 },
          "step" => { "type" => "text", "input_type" => "number", "default" => 1, "width" => 33 }
        } }
      ]

      def pre_process(value) = value.nil? || value == "" ? nil : value
      def process(value) = number(value)

      def rules = [ "numeric", "min:#{config('min')}", "max:#{config('max')}" ]

      def json_schema
        { "type" => whole? ? "integer" : "number", "minimum" => bound("min"), "maximum" => bound("max"), "multipleOf" => bound("step") }
      end

      def ts_type = "number | null"

      private

      def bound(key) = BigDecimal(config(key).to_s).to_f

      def whole? = %w[min max step].all? { |key| bound(key) == bound(key).to_i }

      def number(value)
        return nil if value.nil? || value == ""

        float = Float(value.to_s.strip)
        whole? && float == float.to_i ? float.to_i : float
      rescue ArgumentError, TypeError
        value
      end
    end
  end
end
