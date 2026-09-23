module Nibble
  module Fieldtypes
    class Select < Fieldtype
      include HasSelectOptions

      self.categories = %w[controls]
      self.contract_samples = [ "a", nil ]
      self.keywords = %w[select option choice dropdown list]
      self.selectable_in_forms = true
      self.index_component_name = "tags"
      self.config_field_items = [
        { "display" => "Selection & Options", "fields" => {
          "options" => { "type" => "list", "default" => [], "width" => 50 },
          "taggable" => { "type" => "toggle", "default" => false, "width" => 50 }
        } },
        { "display" => "Appearance", "fields" => {
          "placeholder" => { "type" => "text", "default" => "", "width" => 50 },
          "clearable" => { "type" => "toggle", "default" => false, "width" => 50 },
          "searchable" => { "type" => "toggle", "default" => true, "width" => 50 }
        } },
        { "display" => "Boundaries & Limits", "fields" => {
          "multiple" => { "type" => "toggle", "default" => false, "width" => 50 },
          "max_items" => { "type" => "integer", "width" => 50, "if" => { "multiple" => true } }
        } },
        { "display" => "Data & Format", "fields" => {
          "cast_booleans" => { "type" => "toggle", "default" => false, "width" => 50 }
        } }
      ]

      def rules
        max = config("max_items").to_i
        [ *super, *("max:#{max}" if multiple? && max.positive?) ]
      end
    end
  end
end
