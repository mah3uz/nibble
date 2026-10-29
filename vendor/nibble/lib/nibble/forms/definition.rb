module Nibble
  module Forms
    module Definition
      FIELD_CONFIG = %w[placeholder input_type character_limit default width multiple inline max_files max_file_size extensions prepend append min max step
        autocomplete rows inline_label time_enabled earliest_date latest_date max_items clearable formula decimals].freeze
      OPTION_TYPES = %w[select radio checkboxes].freeze
      LOCALIZED_CONFIG = %w[placeholder inline_label].freeze
      CLIENT_MESSAGES = %w[too_large generic network].freeze
      TIMESTAMP_FIELD = "_nibble_t".freeze

      module_function

      def call(form, result: nil, params: {}, locale: nil)
        captcha = ({ "provider" => nil, "site_key" => nil }.merge(Integrations.captcha.to_h.slice("provider", "site_key"))) if form.captcha?
        fields = form.fields
        closed = form.closed?
        Dependencies.add(Dependencies::UNCACHEABLE) if form.uncacheable?
        {
          "handle" => form.handle,
          "title" => form.title(locale),
          "action" => action(form, fields, params),
          "honeypot" => form.honeypot,
          "captcha" => captcha,
          "fields" => fields.all.values.map { |field| field_definition(field, params, locale) },
          "sections" => form.sections(locale:)&.map { |section| section.merge("fields" => section["fields"].handles) },
          "success" => form.success(locale).slice("message", "redirect"),
          "messages" => CLIENT_MESSAGES.to_h { |key| [ key, Forms.message("client.#{key}", locale) ] },
          "closed" => closed,
          "closed_message" => (Localized.resolve(form.closed_message, locale) if closed),
          "timestamp" => (verifier.generate(Time.current.to_f, purpose: purpose(form)) if form.min_seconds),
          "result" => (result if result.is_a?(Hash) && result["handle"] == form.handle)
        }
      end

      def rendered_at(form, token)
        verifier.verified(token.to_s, purpose: purpose(form)) if token.is_a?(String)
      end

      def verifier = Rails.application.message_verifier("nibble/forms/timestamp")
      def purpose(form) = "form:#{form.handle}"

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

      def field_definition(field, params = {}, locale = nil)
        config = field.fieldtype.config.slice(*FIELD_CONFIG).compact
        LOCALIZED_CONFIG.each { |key| config[key] = Localized.resolve(config[key], locale) if config.key?(key) }
        config["options"] = field.fieldtype.options(locale) if OPTION_TYPES.include?(field.type)
        config["default"] = public_default(field) if config.key?("default")
        if field.get("hidden") == true
          config["hidden"] = true
          config["value"] = config["default"] = prefill_value(field, params) || field.get("value")
          config.compact!
        end
        conditions = Conditions.describe(field.config, prefix: field.prefix)
        config["conditions"] = conditions if conditions
        { "handle" => field.handle, "type" => field.type, "display" => field.display(locale), "instructions" => field.instructions(locale),
          "required" => field.required? }.merge(config)
      end
    end
  end
end
