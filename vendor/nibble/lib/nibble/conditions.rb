module Nibble
  # Semantics must stay identical to the CP's JS evaluator: the server re-checks what the editor saw.
  module Conditions
    KEYS = %w[if if_any show_when show_when_any unless unless_any hide_when hide_when_any].freeze
    OPERATORS = [ "equals", "not", "contains", "contains_any", "===", "!==", ">", ">=", "<", "<=", "custom" ].freeze
    ALIASES = { "is" => "equals", "==" => "equals", "isnt" => "not", "!=" => "not", "includes" => "contains", "includes_any" => "contains_any" }.freeze
    NUMERIC = %w[> >= < <=].freeze
    ROOT_PREFIX = /\A\$?root\./

    Condition = Data.define(:field, :operator, :value)
    Context = Data.define(:values, :root_values, :path) do
      def self.for(values:, root_values: nil, path: nil) = new(values:, root_values: root_values || values, path:)
    end

    class << self
      def register(name, &block) = custom[name.to_s] = block
      def unregister(name) = custom.delete(name.to_s)
      def reset! = @custom = nil

      def visible?(field_config, values:, root_values: nil, path: nil, prefix: nil)
        config = field_config.to_h.stringify_keys
        key = KEYS.find { |candidate| js_truthy?(config[candidate]) } or return true
        context = Context.for(values: values.to_h.stringify_keys, root_values: root_values&.to_h&.stringify_keys, path:)

        conditions = config[key]
        passed = if conditions.is_a?(String)
          passes_custom?(prepare_custom(conditions, nil), context)
        else
          prepared = parse(conditions, prefix).map { |condition| evaluate(condition, context) }
          key.include?("any") ? prepared.any? : prepared.all?
        end
        key.start_with?("unless", "hide_when") ? !passed : passed
      end

      def parse(conditions, prefix = nil)
        conditions.to_h.flat_map do |handle, rhs|
          Array.wrap(rhs).map { |value| split_rhs(handle.to_s, value, prefix) }
        end
      end

      private

      def custom = @custom ||= {}

      def split_rhs(handle, rhs, prefix)
        string = normalize_condition_string(rhs)
        matching = (OPERATORS + ALIASES.keys).select { |operator| string.match?(/\A#{Regexp.escape(operator)} [^=]/) }
        operator = ALIASES.fetch(matching.last || "==", matching.last || "==")
        value = matching.reduce(string) { |remaining, op| remaining.sub(/\A#{Regexp.escape(op)} */, "") }
        scoped = handle.start_with?("$root.", "root.", "$parent.") || prefix.nil? ? handle : "#{prefix}#{handle}"
        Condition.new(field: scoped, operator:, value:)
      end

      def normalize_condition_string(value)
        return "null" if value.nil?
        return "empty" if value == ""

        value.to_s
      end

      def evaluate(condition, context)
        return passes_custom?(prepare_custom(condition.value, condition.field), context) if condition.operator == "custom"

        operator = js_operator(condition.operator)
        raw = field_value(condition.field, context)
        case operator
        when "includes" then includes?(raw, condition.value)
        when "includes_any" then includes_any?(prepare_lhs(raw, operator), condition.value)
        else compare(prepare_lhs(raw, operator), operator, prepare_rhs(condition.value, operator))
        end
      end

      def js_operator(operator)
        case operator
        when nil, "", "is", "equals" then "=="
        when "isnt", "not" then "!="
        when "includes", "contains" then "includes"
        when "includes_any", "contains_any" then "includes_any"
        else operator
        end
      end

      def prepare_lhs(value, operator)
        return js_number(value) if NUMERIC.include?(operator)
        return nil if value.is_a?(String) && value.empty?

        value.is_a?(String) ? value.strip : value
      end

      def prepare_rhs(value, operator)
        case value
        when "null" then nil
        when "true" then true
        when "false" then false
        else NUMERIC.include?(operator) ? js_number(value) : (value == "empty" ? :empty : value.strip)
        end
      end

      def compare(lhs, operator, rhs)
        if rhs == :empty
          lhs = empty?(lhs)
          rhs = true
        end
        return false if lhs.is_a?(Hash) || lhs.is_a?(Array)

        case operator
        when "==" then loose_equal?(lhs, rhs)
        when "!=" then !loose_equal?(lhs, rhs)
        when "===" then strict_equal?(lhs, rhs)
        when "!==" then !strict_equal?(lhs, rhs)
        when ">", ">=", "<", "<=" then !lhs.nan? && !rhs.nan? && lhs.public_send(operator, rhs)
        else false
        end
      end

      def includes?(value, needle)
        case value
        when Array then value.include?(needle)
        when Hash then false
        when nil, false, 0, "" then "".include?(needle)
        else value.to_s.include?(needle)
        end
      end

      def includes_any?(value, needles)
        options = needles.split(",").map(&:strip)
        return value.intersect?(options) if value.is_a?(Array)

        Regexp.new(options.join("|")).match?(js_string(value))
      end

      def js_string(value)
        case value
        when nil then "null"
        when String then value.to_json
        else value.to_s
        end
      end

      def js_truthy?(value) = !(value.nil? || value == false || value == "" || value == 0)

      def empty?(value)
        case value
        when nil then true
        when Numeric, true, false then false
        when Array, Hash, String then value.empty?
        else false
        end
      end

      def loose_equal?(lhs, rhs)
        return lhs.nil? && rhs.nil? if lhs.nil? || rhs.nil?
        return lhs == rhs if lhs.instance_of?(rhs.class) || (lhs.is_a?(Numeric) && rhs.is_a?(Numeric))
        return lhs == rhs if [ true, false ].include?(lhs) && [ true, false ].include?(rhs)

        left = js_number(lhs)
        right = js_number(rhs)
        !left.nan? && !right.nan? && left == right
      end

      def strict_equal?(lhs, rhs)
        return lhs == rhs if lhs.is_a?(Numeric) && rhs.is_a?(Numeric)

        lhs.instance_of?(rhs.class) && lhs == rhs
      end

      def js_number(value)
        case value
        when nil, false then 0.0
        when true then 1.0
        when Numeric then value.to_f
        when String
          stripped = value.strip
          stripped.empty? ? 0.0 : (Float(stripped, exception: false) || Float::NAN)
        else Float::NAN
        end
      end

      def field_value(handle, context)
        handle = ParentResolver.new(context.path).resolve(handle) if handle.start_with?("$parent.")
        if handle.match?(ROOT_PREFIX)
          dig(context.root_values, handle.sub(ROOT_PREFIX, ""))
        else
          dig(context.values, handle)
        end
      end

      def dig(values, dotted)
        dotted.split(".").reduce(values) do |current, key|
          case current
          when Hash then current[key]
          when Array then key.match?(/\A\d+\z/) ? current[key.to_i] : nil
          end
        end
      end

      def prepare_custom(value, target_field)
        name, params = value.to_s.delete_prefix("custom ").split(":", 2)
        { name:, params: params.to_s.split(",").map(&:strip).reject(&:empty?), target_field: }
      end

      def passes_custom?(condition, context)
        callable = custom[condition[:name]] or raise Error, "field condition '#{condition[:name]}' isn't registered"
        target = condition[:target_field] && field_value(condition[:target_field], context)
        callable.call(params: condition[:params], target:, target_handle: condition[:target_field], values: context.values,
          root_values: context.root_values, path: context.path) ? true : false
      end
    end

    class ParentResolver
      PARENT_PATH = /\A(.*?[^.]+)((?:\.[0-9]+)*)\.[^.]*\z/

      def initialize(current_path)
        @current_path = current_path.to_s
      end

      def resolve(path_with_parent)
        parent = parent_path(@current_path, remove_current: true)
        remaining = path_with_parent.delete_prefix("$parent.")
        while remaining.start_with?("$parent.")
          parent = parent_path(parent)
          remaining = remaining.delete_prefix("$parent.")
        end
        "$root.#{parent.empty? ? remaining : "#{parent}.#{remaining}"}"
      end

      private

      def parent_path(path, remove_current: false)
        path = path.sub(PARENT_PATH, '\1') if remove_current || path.match?(/\.[0-9]+\z/)
        path.include?(".") ? path.sub(PARENT_PATH, '\1\2') : ""
      end
    end
  end
end
