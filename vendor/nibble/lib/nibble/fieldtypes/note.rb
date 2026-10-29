module Nibble
  module Fieldtypes
    class Note < Fieldtype
      self.categories = %w[special]
      self.keywords = %w[text paragraph help consent notice]
      self.selectable_in_forms = true
      self.localizable = false
      self.validatable = false
      self.defaultable = false
      self.display_only = true
      self.config_field_items = [
        { "display" => "Text", "fields" => {
          "text" => { "type" => "textarea", "instructions" => "Markdown: paragraphs, emphasis, lists and links." }
        } }
      ]

      def process(_value) = nil
      def publish_config(config) = config.merge("text_html" => html)

      def html(locale = nil)
        text = Localized.resolve(config("text"), locale)
        SafeMarkdown.html(text) if text.present?
      end

      def json_schema = { "type" => "null", "readOnly" => true }
      def ts_type = "never"
    end
  end
end
