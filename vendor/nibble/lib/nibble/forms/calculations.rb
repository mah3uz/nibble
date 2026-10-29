module Nibble
  module Forms
    # The same walk as `calculate` in frontend/nibble/formula.ts, so a visitor sees the total the server stores.
    class Calculations
      TYPE = "calculation".freeze
      NUMERIC_TYPES = %w[integer toggle calculation].freeze
      CHOICE_TYPES = %w[select radio].freeze

      def self.of(fields) = fields.all.values.select { |field| field.type == TYPE }

      def self.problems(fields)
        calculations = of(fields)
        handles = calculations.map(&:handle)
        problems = calculations.flat_map { |field| field_problems(field, fields) }
        calculations.each do |field|
          through = cycle(field, fields, [])
          problems << "field '#{field.handle}' is calculated from itself, through #{through.join(' → ')}" if through&.last == field.handle
        end
        fields.all.each_value do |field|
          rules = Conditions.describe(field.config, prefix: field.prefix)&.fetch("rules") || []
          rules.map { |rule| rule["field"].to_s.sub(Conditions::ROOT_PREFIX, "") }.uniq.intersection(handles).each do |handle|
            problems << "field '#{field.handle}' has a condition on '#{handle}', a calculation, which a condition can't read"
          end
        end
        problems
      end

      def self.field_problems(field, fields)
        label = "field '#{field.handle}'"
        problems = %w[required hidden].select { |key| field.get(key) == true }.map { |key| "#{label} is a calculation, which can't be #{key}" }
        decimals = field.get("decimals")
        unless decimals.nil? || (decimals.is_a?(Integer) && decimals.between?(0, Formula::MAX_DIGITS))
          problems << "#{label} decimals must be a whole number from 0 to #{Formula::MAX_DIGITS}"
        end
        return problems << "#{label} needs a `formula`" unless field.get("formula").is_a?(String)

        formula = Formula.new(field.get("formula"))
        formula.references.each do |handle|
          other = fields.get(handle)
          if other.nil?
            problems << "#{label} has a formula naming {#{handle}}, which isn't one of the form's fields"
          elsif !numeric?(other)
            problems << "#{label} has a formula naming {#{handle}}, a #{other.type} field that doesn't hold a number"
          end
        end
        problems
      rescue Formula::Error => error
        problems << "#{label} has a formula that doesn't parse: #{error.message}"
      end

      def self.numeric?(field)
        return true if NUMERIC_TYPES.include?(field.type)
        return false unless CHOICE_TYPES.include?(field.type) && field.get("multiple") != true

        options = field.fieldtype.options
        options.any? && options.all? { |option| Formula::NUMBER.match?(option["value"].to_s) }
      end

      def self.references(field)
        Formula.new(field.get("formula")).references
      rescue Formula::Error
        []
      end

      def self.cycle(field, fields, path)
        return [ *path, field.handle ] if path.include?(field.handle)

        references(field).lazy.filter_map do |handle|
          other = fields.get(handle)
          cycle(other, fields, [ *path, field.handle ]) if other&.type == TYPE
        end.first
      end

      def initialize(fields, data)
        @fields = fields
        @data = data
        @results = {}
      end

      def values = self.class.of(@fields).to_h { |field| [ field.handle, value(field, []) ] }

      private

      def value(field, path)
        return @results[field.handle] if @results.key?(field.handle)
        return nil if path.include?(field.handle) || !visible?(field)

        formula = Formula.new(field.get("formula"))
        inputs = formula.references.to_h { |handle| [ handle, input(@fields.get(handle), [ *path, field.handle ]) ] }
        @results[field.handle] = formula.evaluate(inputs, decimals: field.get("decimals"))
      rescue Formula::Error
        @results[field.handle] = nil
      end

      def input(field, path)
        return nil unless field && visible?(field)

        field.type == TYPE ? value(field, path) : @data[field.handle]
      end

      def visible?(field) = Conditions.visible?(field.config, values: @data, prefix: field.prefix)
    end
  end
end
