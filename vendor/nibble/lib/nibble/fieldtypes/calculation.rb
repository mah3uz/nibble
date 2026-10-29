module Nibble
  module Fieldtypes
    class Calculation < Fieldtype
      self.categories = %w[number]
      self.keywords = %w[formula total sum quote price]
      self.selectable = false
      self.selectable_in_forms = true
      self.localizable = false
      self.validatable = false
      self.defaultable = false
      self.component_name = "text"
      self.config_field_items = [
        { "display" => "Data and format", "fields" => {
          "formula" => { "type" => "text", "instructions" => "Like `{quantity} * {unit_price}`." },
          "decimals" => { "type" => "integer", "min" => 0, "max" => Forms::Formula::MAX_DIGITS, "width" => 33 },
          "prepend" => { "type" => "text", "width" => 33 },
          "append" => { "type" => "text", "width" => 33 }
        } }
      ]

      # A posted value is dropped here, on every path: Forms::Calculations adds the server's own afterwards.
      def process(_value) = nil

      def pre_process(raw) = rounded(raw)

      def display(value)
        number = rounded(value)
        "#{config('prepend')}#{number}#{config('append')}" if number
      end

      def json_schema = { "type" => "number", "readOnly" => true, "description" => "Calculated when the form is submitted; a value sent is ignored" }
      def ts_type = "number | null"

      private

      def rounded(value)
        return nil unless value.is_a?(Numeric)

        decimals = config("decimals")
        ActiveSupport::NumberHelper.number_to_rounded(value, precision: decimals || 10, strip_insignificant_zeros: decimals.nil?, delimiter: ",")
      end
    end
  end
end
