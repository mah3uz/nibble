module Nibble
  module Fieldtypes
    class Toggle < Fieldtype
      self.categories = %w[controls]
      self.contract_samples = [ true, false ]
      self.keywords = %w[checkbox bool boolean]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Appearance", "fields" => {
          "inline_label" => { "type" => "text", "default" => "", "width" => 50 },
          "inline_label_when_true" => { "type" => "text", "default" => "", "width" => 50 }
        } }
      ]

      def default_value = false
      def pre_process(value) = truthy?(value)
      def process(value) = value.nil? ? nil : truthy?(value)
      def augment(value) = truthy?(value)
      def ts_type = "boolean"

      private

      def truthy?(value) = ![ nil, false, 0, "0", "", "false" ].include?(value)
    end
  end
end
