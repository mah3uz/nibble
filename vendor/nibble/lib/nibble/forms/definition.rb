module Nibble
  module Forms
    module Definition
      FIELD_CONFIG = %w[placeholder input_type character_limit default width multiple inline max_files max_file_size extensions prepend append min max step
        autocomplete rows inline_label time_enabled earliest_date latest_date max_items clearable].freeze
      OPTION_TYPES = %w[select radio checkboxes].freeze

      module_function

      def call(form, result: nil)
        captcha = ({ "provider" => nil, "site_key" => nil }.merge(Integrations.captcha.to_h.slice("provider", "site_key"))) if form.captcha?
        {
          "handle" => form.handle,
          "title" => form.title,
          "action" => "/forms/#{form.handle}",
          "honeypot" => form.honeypot,
          "captcha" => captcha,
          "fields" => form.fields.all.values.map { |field| field_definition(field) },
          "sections" => sections(form),
          "success" => form.success.slice("message", "redirect"),
          "result" => (result if result.is_a?(Hash) && result["handle"] == form.handle)
        }
      end

      def sections(form)
        form.sections&.map do |section|
          { "display" => section["display"], "instructions" => section["instructions"], "fields" => section["fields"].handles }
        end
      end

      def field_definition(field)
        config = field.fieldtype.config.slice(*FIELD_CONFIG).compact
        config["options"] = field.fieldtype.options if OPTION_TYPES.include?(field.type)
        config["default"] = field.default_value if config.key?("default")
        conditions = Conditions.describe(field.config, prefix: field.prefix)
        config["conditions"] = conditions if conditions
        { "handle" => field.handle, "type" => field.type, "display" => field.display, "instructions" => field.instructions,
          "required" => field.required? }.merge(config)
      end
    end
  end
end
