module Nibble
  module Fieldtypes
    class Toggle < Fieldtype
      OFF = [ nil, false, 0, "0", "", "false" ].freeze

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

      def publish_config(config)
        label = Localized.resolve(config["inline_label"])
        SafeMarkdown.link?(label) ? config.merge("inline_label" => SafeMarkdown.label_text(label), "inline_label_html" => SafeMarkdown.label_html(label)) : config
      end

      def default_value = false
      def pre_process(value) = truthy?(value)
      def process(value) = value.nil? ? nil : truthy?(value)
      def augment(value) = truthy?(value)
      def pre_process_index(value) = truthy?(value) ? "Yes" : "No"
      def ts_type = "boolean"

      private

      def truthy?(value) = !OFF.include?(value)
    end
  end
end
