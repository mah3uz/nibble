module Nibble
  module Fieldtypes
    class Integer < Fieldtype
      self.categories = %w[number]
      self.contract_samples = [ 0, 42, nil ]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Appearance", "fields" => {
          "placeholder" => { "type" => "text" },
          "prepend" => { "type" => "text", "width" => 50 },
          "append" => { "type" => "text", "width" => 50 }
        } },
        { "display" => "Data & Format", "fields" => {
          "min" => { "type" => "integer", "width" => 33 },
          "max" => { "type" => "integer", "width" => 33 },
          "step" => { "type" => "integer", "width" => 33 }
        } }
      ]

      def pre_process(value) = value.nil? ? nil : value.to_i
      def process(value) = value.nil? || value == "" ? nil : value.to_i

      def rules
        [ "integer", *("min:#{config('min')}" unless config("min").nil?), *("max:#{config('max')}" unless config("max").nil?) ]
      end

      def ts_type = "number | null"
    end
  end
end
