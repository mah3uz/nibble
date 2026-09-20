module Nibble
  module Fieldtypes
    class Textarea < Fieldtype
      self.categories = %w[text]
      self.contract_samples = [ "Line one\nLine two" ]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Appearance", "fields" => {
          "placeholder" => { "type" => "text", "width" => 50 },
          "character_limit" => { "type" => "integer", "width" => 50 },
          "rows" => { "type" => "integer", "width" => 50 }
        } }
      ]

      def rules = config("character_limit").to_i.positive? ? [ "max:#{config('character_limit')}" ] : []
      def search_text(value) = value.is_a?(String) ? value : nil
      def ts_type = "string | null"
    end
  end
end
