module Nibble
  module Validation
    Rule = Data.define(:name, :params)

    IMPLICIT = %w[required required_if required_unless required_with required_without accepted].freeze
    EMAIL = URI::MailTo::EMAIL_REGEXP

    MESSAGES = {
      "required" => "%{attribute} is required.",
      "required_if" => "%{attribute} is required when %{other} is %{value}.",
      "required_unless" => "%{attribute} is required unless %{other} is in %{values}.",
      "required_with" => "%{attribute} is required when %{values} is present.",
      "required_without" => "%{attribute} is required when %{values} is not present.",
      "accepted" => "%{attribute} must be accepted.",
      "string" => "%{attribute} must be text.",
      "numeric" => "%{attribute} must be a number.",
      "integer" => "%{attribute} must be a whole number.",
      "boolean" => "%{attribute} must be true or false.",
      "array" => "%{attribute} must be a list.",
      "min.numeric" => "%{attribute} must be at least %{min}.",
      "min.string" => "%{attribute} must be at least %{min} characters.",
      "min.array" => "%{attribute} must have at least %{min} items.",
      "max.numeric" => "%{attribute} must not be greater than %{max}.",
      "max.string" => "%{attribute} must not be greater than %{max} characters.",
      "max.array" => "%{attribute} must not have more than %{max} items.",
      "between.numeric" => "%{attribute} must be between %{min} and %{max}.",
      "between.string" => "%{attribute} must be between %{min} and %{max} characters.",
      "between.array" => "%{attribute} must have between %{min} and %{max} items.",
      "size.numeric" => "%{attribute} must be %{size}.",
      "size.string" => "%{attribute} must be %{size} characters.",
      "size.array" => "%{attribute} must contain %{size} items.",
      "email" => "%{attribute} must be a valid email address.",
      "url" => "%{attribute} must be a valid URL.",
      "phone" => "%{attribute} must be a valid phone number.",
      "safe_link" => "%{attribute} must be a web, email or phone link, or a link to content on this site.",
      "alpha" => "%{attribute} must only contain letters.",
      "alpha_num" => "%{attribute} must only contain letters and numbers.",
      "alpha_dash" => "%{attribute} must only contain letters, numbers, dashes, and underscores.",
      "regex" => "%{attribute} isn't in the expected format.",
      "not_regex" => "%{attribute} isn't in the expected format.",
      "in" => "Choose one of the options for %{attribute}.",
      "not_in" => "Choose one of the options for %{attribute}.",
      "lowercase" => "%{attribute} must be lowercase.",
      "uppercase" => "%{attribute} must be uppercase.",
      "starts_with" => "%{attribute} must start with one of the following: %{values}.",
      "ends_with" => "%{attribute} must end with one of the following: %{values}.",
      "date" => "%{attribute} must be a valid date.",
      "after" => "%{attribute} must be a date after %{date}.",
      "after_or_equal" => "%{attribute} must be a date after or equal to %{date}.",
      "before" => "%{attribute} must be a date before %{date}.",
      "before_or_equal" => "%{attribute} must be a date before or equal to %{date}.",
      "local_time" => "%{attribute} is a time the clocks skip in %{zone}. Choose a time outside the hour they go forward.",
      "time" => "%{attribute} must be a time of day on the 24-hour clock, such as 14:30.",
      "earliest_time" => "%{attribute} must be %{time} or later.",
      "latest_time" => "%{attribute} must be %{time} or earlier.",
      "color" => "%{attribute} must be a colour written as #rrggbb, such as #1a2b3c.",
      "same" => "%{attribute} must match %{other}.",
      "different" => "%{attribute} and %{other} must be different.",
      "mimes" => "%{attribute} must be a file of type: %{values}.",
      "max_file_size" => "Each %{attribute} file must not be larger than %{max} MB.",
      "max_of_set" => "%{attribute} must not have more than %{max} %{set} blocks.",
      "records_exist" => "%{attribute} contains items that don't exist or aren't allowed here.",
      "max_text" => "%{attribute} must not be longer than %{max} characters of text.",
      "global_links" => "%{attribute} links to %{refs}, which isn't a web address field of a site setting."
    }.freeze

    class << self
      # A custom rule block returns nil when the value passes, or an error message.
      def register(name, implicit: false, &check)
        custom[name.to_s] = { check:, implicit: }
      end

      def unregister(name) = custom.delete(name.to_s)
      def reset! = @custom = nil
      def custom_rule(name) = custom[name.to_s]

      def known?(name) = BUILT_IN.include?(name.to_s) || custom.key?(name.to_s)

      def explode(rules)
        return [] if rules.blank?

        rules.is_a?(String) ? rules.split("|") : Array(rules)
      end

      def parse(rule, prefix: "", replacements: {})
        rule = rule.to_s
        unless rule.start_with?("regex:", "not_regex:")
          rule = rule.gsub("{this}.", prefix.to_s).gsub(/\{\s*([a-zA-Z0-9_-]+)\s*\}/) { replacements.fetch(Regexp.last_match(1).to_sym, replacements.fetch(Regexp.last_match(1), "NULL")).to_s }
        end
        name, params = rule.split(":", 2)
        params = if params.nil? then []
        elsif %w[regex not_regex].include?(name) then [ params ]
        else params.split(",", -1)
        end
        Rule.new(name:, params:)
      end

      def message(key, override: nil, locale: nil, default: nil, **values)
        custom = custom_message(override, locale)
        return I18n.interpolate(custom, **values) if custom

        I18n.t("nibble.validation.#{key}", locale: Localized.i18n_locale(locale), default: default || MESSAGES.fetch(key), **values)
      end

      private

      def custom_message(override, locale)
        return override if override.is_a?(String)
        return unless override.is_a?(Hash)

        override[(locale || I18n.locale).to_s] || override[Nibble.config.default_locale.code.to_s]
      end

      def custom = @custom ||= {}
    end

    BUILT_IN = (MESSAGES.keys.map { |key| key.split(".").first } + %w[nullable sometimes]).uniq.freeze
  end
end
