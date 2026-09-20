module Nibble
  module Validation
    Rule = Data.define(:name, :params)

    IMPLICIT = %w[required required_if required_unless required_with required_without accepted].freeze
    EMAIL = URI::MailTo::EMAIL_REGEXP

    MESSAGES = {
      "required" => "The %{attribute} field is required.",
      "required_if" => "The %{attribute} field is required when %{other} is %{value}.",
      "required_unless" => "The %{attribute} field is required unless %{other} is in %{values}.",
      "required_with" => "The %{attribute} field is required when %{values} is present.",
      "required_without" => "The %{attribute} field is required when %{values} is not present.",
      "accepted" => "The %{attribute} field must be accepted.",
      "string" => "The %{attribute} field must be a string.",
      "numeric" => "The %{attribute} field must be a number.",
      "integer" => "The %{attribute} field must be an integer.",
      "boolean" => "The %{attribute} field must be true or false.",
      "array" => "The %{attribute} field must be an array.",
      "min.numeric" => "The %{attribute} field must be at least %{min}.",
      "min.string" => "The %{attribute} field must be at least %{min} characters.",
      "min.array" => "The %{attribute} field must have at least %{min} items.",
      "max.numeric" => "The %{attribute} field must not be greater than %{max}.",
      "max.string" => "The %{attribute} field must not be greater than %{max} characters.",
      "max.array" => "The %{attribute} field must not have more than %{max} items.",
      "between.numeric" => "The %{attribute} field must be between %{min} and %{max}.",
      "between.string" => "The %{attribute} field must be between %{min} and %{max} characters.",
      "between.array" => "The %{attribute} field must have between %{min} and %{max} items.",
      "size.numeric" => "The %{attribute} field must be %{size}.",
      "size.string" => "The %{attribute} field must be %{size} characters.",
      "size.array" => "The %{attribute} field must contain %{size} items.",
      "email" => "The %{attribute} field must be a valid email address.",
      "url" => "The %{attribute} field must be a valid URL.",
      "alpha" => "The %{attribute} field must only contain letters.",
      "alpha_num" => "The %{attribute} field must only contain letters and numbers.",
      "alpha_dash" => "The %{attribute} field must only contain letters, numbers, dashes, and underscores.",
      "regex" => "The %{attribute} field format is invalid.",
      "not_regex" => "The %{attribute} field format is invalid.",
      "in" => "The selected %{attribute} is invalid.",
      "not_in" => "The selected %{attribute} is invalid.",
      "lowercase" => "The %{attribute} field must be lowercase.",
      "uppercase" => "The %{attribute} field must be uppercase.",
      "starts_with" => "The %{attribute} field must start with one of the following: %{values}.",
      "ends_with" => "The %{attribute} field must end with one of the following: %{values}.",
      "date" => "The %{attribute} field must be a valid date.",
      "after" => "The %{attribute} field must be a date after %{date}.",
      "after_or_equal" => "The %{attribute} field must be a date after or equal to %{date}.",
      "before" => "The %{attribute} field must be a date before %{date}.",
      "before_or_equal" => "The %{attribute} field must be a date before or equal to %{date}.",
      "same" => "The %{attribute} field must match %{other}.",
      "different" => "The %{attribute} field and %{other} must be different.",
      "mimes" => "The %{attribute} field must be a file of type: %{values}.",
      "max_file_size" => "Each %{attribute} file must not be larger than %{max} MB.",
      "records_exist" => "The %{attribute} field contains items that don't exist or aren't allowed here."
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

      def message(key, **values)
        I18n.t("nibble.validation.#{key}", default: MESSAGES.fetch(key), **values)
      end

      private

      def custom = @custom ||= {}
    end

    BUILT_IN = (MESSAGES.keys.map { |key| key.split(".").first } + %w[nullable sometimes]).uniq.freeze
  end
end
