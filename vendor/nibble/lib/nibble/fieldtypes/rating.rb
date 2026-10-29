module Nibble
  module Fieldtypes
    class Rating < Fieldtype
      self.categories = %w[number controls]
      self.keywords = %w[stars score review]
      self.contract_samples = [ 1, 4, nil ]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Data and format", "fields" => {
          "max" => { "type" => "integer", "default" => 5, "min" => 2, "max" => 10, "width" => 33 }
        } }
      ]

      def pre_process(value) = value.nil? || value == "" ? nil : value
      def process(value) = value.nil? || value == "" ? nil : (value.to_s.match?(/\A\d+\z/) ? value.to_i : value)

      def rules = [ "integer", "min:1", "max:#{limit}" ]

      def json_schema = { "type" => "integer", "minimum" => 1, "maximum" => limit }

      def ts_type = "number | null"

      private

      def limit = config("max").to_i.clamp(2, 10)
    end
  end
end
