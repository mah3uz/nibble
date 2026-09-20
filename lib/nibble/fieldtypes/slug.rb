module Nibble
  module Fieldtypes
    class Slug < Text
      self.categories = %w[special]
      self.contract_samples = [ "hello-world" ]
      self.selectable_in_forms = false
      self.config_field_items = [
        { "display" => "Input Behavior", "fields" => {
          "generate" => { "type" => "toggle", "default" => true, "width" => 50 },
          "from" => { "type" => "text", "default" => "title", "width" => 50 },
          "separator" => { "type" => "text", "default" => "-", "width" => 50 },
          "show_regenerate" => { "type" => "toggle", "default" => false, "width" => 50 }
        } }
      ]

      def rules = []
      def ts_type = "string | null"
    end
  end
end
