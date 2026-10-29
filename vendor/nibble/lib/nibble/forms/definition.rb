module Nibble
  module Forms
    module Definition
      FIELD_CONFIG = %w[placeholder input_type character_limit default width multiple inline max_files max_file_size extensions prepend append min max step
        autocomplete rows inline_label time_enabled earliest_date latest_date max_items clearable].freeze
      OPTION_TYPES = %w[select radio checkboxes].freeze

      module_function

      def call(form, result: nil, params: {})
        captcha = ({ "provider" => nil, "site_key" => nil }.merge(Integrations.captcha.to_h.slice("provider", "site_key"))) if form.captcha?
        fields = form.fields
        {
          "handle" => form.handle,
          "title" => form.title,
          "action" => action(form, fields, params),
          "honeypot" => form.honeypot,
          "captcha" => captcha,
          "fields" => fields.all.values.map { |field| field_definition(field, params) },
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

      def prefill_params(form) = form.fields.all.values.filter_map { |field| prefill_name(field) }.uniq

      def prefill_name(field)
        field.get("prefill", {})["query"] if field.get("hidden") == true
      end

      def prefill_value(field, params)
        queried = params[prefill_name(field)]
        queried.truncate(Submit::PREFILL_LIMIT, omission: "") if queried.is_a?(String) && queried.present?
      end

      def action(form, fields, params)
        queried = fields.all.values.to_h { |field| [ prefill_name(field), prefill_value(field, params) ] }.compact
        queried.delete(nil)
        queried.empty? ? "/forms/#{form.handle}" : "/forms/#{form.handle}?#{queried.to_query}"
      end

      # nibble:check refuses an unknown computed default; a page that still has one shows the form without it.
      def public_default(field)
        field.default_value
      rescue Nibble::Error => error
        Rails.logger.warn("[nibble] form field #{field.path}: #{error.message}")
        nil
      end

      def field_definition(field, params = {})
        config = field.fieldtype.config.slice(*FIELD_CONFIG).compact
        config["options"] = field.fieldtype.options if OPTION_TYPES.include?(field.type)
        config["default"] = public_default(field) if config.key?("default")
        if field.get("hidden") == true
          config["hidden"] = true
          config["value"] = config["default"] = prefill_value(field, params) || field.get("value")
          config.compact!
        end
        conditions = Conditions.describe(field.config, prefix: field.prefix)
        config["conditions"] = conditions if conditions
        { "handle" => field.handle, "type" => field.type, "display" => field.display, "instructions" => field.instructions,
          "required" => field.required? }.merge(config)
      end
    end
  end
end
