module Nibble
  module Forms
    module Definition
      FIELD_CONFIG = %w[placeholder input_type character_limit default width multiple inline max_files max_file_size extensions].freeze
      OPTION_TYPES = %w[select radio checkboxes].freeze

      module_function

      def call(form, result: nil)
        captcha = form.captcha? ? Integrations.captcha : nil
        {
          "handle" => form.handle,
          "title" => form.title,
          "action" => "/forms/#{form.handle}",
          "honeypot" => form.honeypot,
          "captcha" => captcha&.slice("provider", "site_key"),
          "fields" => form.fields.all.values.map { |field| field_definition(field) },
          "success" => form.success.slice("message", "redirect"),
          "result" => (result if result.is_a?(Hash) && result["handle"] == form.handle)
        }
      end

      def field_definition(field)
        config = field.fieldtype.config.slice(*FIELD_CONFIG).compact
        config["options"] = field.fieldtype.options if OPTION_TYPES.include?(field.type)
        { "handle" => field.handle, "type" => field.type, "display" => field.display, "instructions" => field.instructions,
          "required" => field.required? }.merge(config)
      end
    end
  end
end
