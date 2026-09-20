module Nibble
  module Fieldtypes
    class Checkboxes < Fieldtype
      include HasSelectOptions

      self.categories = %w[controls]
      self.contract_samples = [ %w[a b] ]
      self.selectable_in_forms = true
      self.index_component_name = "tags"
      self.config_field_items = [
        { "display" => "Selection & Options", "fields" => { "options" => { "type" => "list", "default" => [] } } },
        { "display" => "Appearance", "fields" => { "inline" => { "type" => "toggle", "default" => false } } }
      ]

      def multiple? = true
      def pre_process_validatable(value) = Array.wrap(value).compact_blank
      def process(value) = super.compact
    end
  end
end
