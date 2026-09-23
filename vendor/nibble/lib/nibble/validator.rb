module Nibble
  class Validator
    Result = Data.define(:errors, :values) do
      def valid? = errors.empty?
    end

    Entry = Data.define(:rules, :attribute)

    ACCEPTED = [ "yes", "on", "1", 1, true, "true" ].freeze
    BOOLEANS = [ true, false, 0, 1, "0", "1" ].freeze

    def self.collect_rules(fields, values, root_values:, prefix: "", replacements: {})
      values = values.to_h.stringify_keys
      fields.each_with_object({}) do |field, rules|
        next if field.computed?

        path = "#{prefix}#{field.handle}"
        next unless field.always_save? || Conditions.visible?(field.config, values:, root_values:, path:, prefix: field.prefix)

        list = [ *("required" if field.get("required") == true), *field.validation_rules, *Validation.explode(field.fieldtype.rules) ]
        parsed = list.uniq.map { |rule| Validation.parse(rule, prefix:, replacements:) }
        rules[path] = Entry.new(rules: parsed, attribute: field.display)
        field.with_value(values[field.handle]).fieldtype.extra_rules(root_values:, prefix: "#{path}.", replacements:).each do |nested_path, entry|
          rules[nested_path] = entry
        end
      end
    end

    def initialize(fields, replacements: {}, skip_required: false)
      @fields = fields
      @replacements = replacements
      @skip_required = skip_required
    end

    def validate(values)
      validatable = @fields.add_values(values.to_h.stringify_keys).pre_process_validatable.values
      rules = self.class.collect_rules(@fields, validatable, root_values: validatable, replacements: @replacements)
      errors = rules.each_with_object({}) do |(path, entry), found|
        messages = check(path, entry, validatable)
        found[path] = messages if messages.any?
      end
      Result.new(errors:, values: validatable)
    end

    private

    def check(path, entry, root)
      present, value = lookup(root, path)
      names = entry.rules.map(&:name)
      return [] if names.include?("sometimes") && !present

      messages = []
      entry.rules.each do |rule|
        next if %w[nullable sometimes].include?(rule.name)
        next if @skip_required && implicit?(rule.name)
        next if !implicit?(rule.name) && blank_input?(value)

        message = run(rule, value, root, names, entry.attribute) or next
        messages << message
        break if implicit?(rule.name)
      end
      messages
    end

    def implicit?(name) = Validation::IMPLICIT.include?(name) || Validation.custom_rule(name)&.dig(:implicit)

    def run(rule, value, root, names, attribute)
      params = rule.params
      message = ->(key, **extra) { Validation.message(key, attribute:, **extra) }
      sized = ->(key, **extra) { message.("#{key}.#{size_type(value, names)}", **extra) }

      case rule.name
      when "required" then message.("required") if blank?(value)
      when "required_if"
        other = params.first
        message.("required_if", other: humanize(other), value: params.drop(1).join(", ")) if matches?(lookup(root, other).last, params.drop(1)) && blank?(value)
      when "required_unless"
        other = params.first
        message.("required_unless", other: humanize(other), values: params.drop(1).join(", ")) if !matches?(lookup(root, other).last, params.drop(1)) && blank?(value)
      when "required_with"
        message.("required_with", values: params.map { |p| humanize(p) }.join(" / ")) if params.any? { |p| !blank?(lookup(root, p).last) } && blank?(value)
      when "required_without"
        message.("required_without", values: params.map { |p| humanize(p) }.join(" / ")) if params.any? { |p| blank?(lookup(root, p).last) } && blank?(value)
      when "accepted" then message.("accepted") unless ACCEPTED.include?(value)
      when "string" then message.("string") unless value.is_a?(String)
      when "numeric" then message.("numeric") unless numeric?(value)
      when "integer" then message.("integer") unless value.is_a?(Integer) || (value.is_a?(String) && value.match?(/\A-?\d+\z/))
      when "boolean" then message.("boolean") unless BOOLEANS.include?(value)
      when "array" then message.("array") unless value.is_a?(Array) || value.is_a?(Hash)
      when "min" then sized.("min", min: params.first) if size(value, names) < params.first.to_f
      when "max" then sized.("max", max: params.first) if size(value, names) > params.first.to_f
      when "between"
        sized.("between", min: params[0], max: params[1]) unless size(value, names).between?(params[0].to_f, params[1].to_f)
      when "size" then sized.("size", size: params.first) unless size(value, names) == params.first.to_f
      when "email" then message.("email") unless value.to_s.match?(/\A#{Validation::EMAIL}\z/)
      when "url" then message.("url") unless url?(value)
      when "alpha" then message.("alpha") unless value.to_s.match?(/\A\p{L}+\z/)
      when "alpha_num" then message.("alpha_num") unless value.to_s.match?(/\A[\p{L}\p{N}]+\z/)
      when "alpha_dash" then message.("alpha_dash") unless value.to_s.match?(/\A[\p{L}\p{N}_-]+\z/)
      when "regex" then message.("regex") unless regex(params.first).match?(value.to_s)
      when "not_regex" then message.("not_regex") if regex(params.first).match?(value.to_s)
      when "in" then message.("in") unless Array.wrap(value).all? { |item| params.include?(item.to_s) }
      when "not_in" then message.("not_in") if Array.wrap(value).any? { |item| params.include?(item.to_s) }
      when "lowercase" then message.("lowercase") unless value.to_s == value.to_s.downcase
      when "uppercase" then message.("uppercase") unless value.to_s == value.to_s.upcase
      when "starts_with" then message.("starts_with", values: params.join(", ")) unless params.any? { |p| value.to_s.start_with?(p) }
      when "ends_with" then message.("ends_with", values: params.join(", ")) unless params.any? { |p| value.to_s.end_with?(p) }
      when "date" then message.("date") unless to_time(value)
      when "after", "after_or_equal", "before", "before_or_equal" then compare_dates(rule.name, value, params.first, root, message)
      when "same" then message.("same", other: humanize(params.first)) unless value == lookup(root, params.first).last
      when "different" then message.("different", other: humanize(params.first)) if value == lookup(root, params.first).last
      when "records_exist" then message.("records_exist") unless records_exist?(value, params)
      when "mimes" then message.("mimes", values: params.join(", ")) unless Array.wrap(value).all? { |file| Forms::Uploads.allowed?(file, params) }
      when "max_file_size"
        message.("max_file_size", max: params.first) if Array.wrap(value).any? { |file| !Forms::Uploads.file?(file) || file.size > params.first.to_i.megabytes }
      else
        custom = Validation.custom_rule(rule.name) or raise Error, "unknown validation rule '#{rule.name}'"
        result = custom[:check].call(value, params:, root_values: root, attribute:)
        result && result.to_s.gsub("%{attribute}", attribute)
      end
    end

    def lookup(root, path)
      current = root
      path.to_s.split(".").each do |key|
        case current
        when Hash
          return [ false, nil ] unless current.key?(key)

          current = current[key]
        when Array
          return [ false, nil ] unless key.match?(/\A\d+\z/) && key.to_i < current.size

          current = current[key.to_i]
        else
          return [ false, nil ]
        end
      end
      [ true, current ]
    end

    def blank?(value)
      case value
      when nil then true
      when String then value.strip.empty?
      when Array, Hash then value.empty?
      else false
      end
    end

    def blank_input?(value) = value.nil? || value == ""

    def matches?(other, expected)
      forms = case other
      when true then %w[true 1]
      when false then %w[false 0]
      when nil then %w[null]
      else [ other.to_s ]
      end
      expected.intersect?(forms)
    end

    def numeric?(value) = value.is_a?(Numeric) || (value.is_a?(String) && Float(value, exception: false))

    def size_type(value, names)
      return "array" if value.is_a?(Array) || value.is_a?(Hash)
      return "numeric" if names.intersect?(%w[numeric integer]) && numeric?(value)

      "string"
    end

    def size(value, names)
      case size_type(value, names)
      when "array" then value.size.to_f
      when "numeric" then value.is_a?(Numeric) ? value.to_f : Float(value)
      else value.to_s.length.to_f
      end
    end

    def url?(value)
      uri = URI.parse(value.to_s)
      uri.scheme.present? && (uri.host.present? || uri.scheme == "mailto")
    rescue URI::InvalidURIError
      false
    end

    def regex(pattern)
      match = pattern.to_s.match(%r{\A(.)(.*)\1([imxsu]*)\z}m) or raise Error, "invalid regex rule '#{pattern}'"
      source = match[2].sub(/\A\^/, '\A').sub(/(?<!\\)\$\z/, '\z')
      options = (match[3].include?("i") ? Regexp::IGNORECASE : 0) | (match[3].include?("x") ? Regexp::EXTENDED : 0) |
        (match[3].include?("s") ? Regexp::MULTILINE : 0)
      Regexp.new(source, options)
    end

    def to_time(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return value.in_time_zone if value.is_a?(Date)
      return nil unless value.is_a?(String) && value.present?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end

    def compare_dates(name, value, reference, root, message)
      time = to_time(value) or return message.("date")
      present, other = lookup(root, reference)
      limit = present ? to_time(other) : relative_time(reference)
      return nil unless limit

      passed = case name
      when "after" then time > limit
      when "after_or_equal" then time >= limit
      when "before" then time < limit
      else time <= limit
      end
      message.(name, date: reference) unless passed
    end

    def relative_time(reference)
      case reference
      when "now" then Time.current
      when "today" then Time.current.beginning_of_day
      when "tomorrow" then Time.current.tomorrow.beginning_of_day
      when "yesterday" then Time.current.yesterday.beginning_of_day
      else to_time(reference)
      end
    end

    def records_exist?(value, params)
      ids = Array.wrap(value).map { |item| item.is_a?(Hash) ? item["asset"] : item }.compact_blank
      return true if ids.empty?

      scope = params.drop(1).to_h { |pair| key, list = pair.split("=", 2); [ key, list.to_s.split(";") ] }
      found = Resolvers.find(params.first).find(ids, scope:).map { |item| item["id"].to_s }
      (ids.map(&:to_s) - found).empty?
    end

    def humanize(path) = path.to_s.split(".").last.to_s.humanize.downcase
  end
end
