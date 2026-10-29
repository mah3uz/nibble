module Nibble
  module Fieldtypes
    class Decimal < Fieldtype
      self.categories = %w[number]
      self.keywords = %w[price money amount currency]
      self.contract_samples = [ 0, 1.5, nil ]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Appearance", "fields" => {
          "placeholder" => { "type" => "text" },
          "prepend" => { "type" => "text", "width" => 50 },
          "append" => { "type" => "text", "width" => 50 }
        } },
        { "display" => "Data & Format", "fields" => {
          "decimals" => { "type" => "integer", "default" => 2, "min" => 0, "max" => 10, "width" => 25 },
          "min" => { "type" => "text", "input_type" => "number", "width" => 25 },
          "max" => { "type" => "text", "input_type" => "number", "width" => 25 },
          "step" => { "type" => "text", "input_type" => "number", "width" => 25, "instructions" => "Defaults to the smallest step the decimals allow." }
        } }
      ]

      def pre_process(value) = value.nil? || value == "" ? nil : value
      def process(value) = number(value)

      def rules
        [ "numeric", *("min:#{config('min')}" unless config("min").blank?), *("max:#{config('max')}" unless config("max").blank?) ]
      end

      def display(value)
        return nil unless value.is_a?(Numeric)

        ActiveSupport::NumberHelper.number_to_rounded(value, precision: places)
      end

      def json_schema
        { "type" => "number", **{ "minimum" => bound("min"), "maximum" => bound("max") }.compact, "multipleOf" => 10.0**-places }
      end

      def ts_type = "number | null"

      private

      def places = config("decimals").to_i.clamp(0, 10)

      def bound(key) = config(key).blank? ? nil : BigDecimal(config(key).to_s).to_f

      def number(value)
        return nil if value.nil? || value == ""

        rounded = BigDecimal(value.to_s.strip).round(places, :half_up)
        places.zero? ? rounded.to_i : rounded.to_f
      rescue ArgumentError, TypeError
        value
      end
    end
  end
end
