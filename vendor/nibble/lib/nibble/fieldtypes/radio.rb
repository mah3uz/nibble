module Nibble
  module Fieldtypes
    class Radio < Fieldtype
      include HasSelectOptions

      self.categories = %w[controls]
      self.contract_samples = [ "a" ]
      self.selectable_in_forms = true
      self.index_component_name = "tags"
      self.config_field_items = [
        { "display" => "Selection and options", "fields" => { "options" => { "type" => "list", "default" => [] } } },
        { "display" => "Appearance", "fields" => { "inline" => { "type" => "toggle", "default" => false } } },
        { "display" => "Data and format", "fields" => { "cast_booleans" => { "type" => "toggle", "default" => false } } }
      ]

      def multiple? = false
    end
  end
end
