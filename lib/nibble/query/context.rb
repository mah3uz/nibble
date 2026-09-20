module Nibble
  class Query
    Context = Data.define(:locale, :now, :entry, :term, :set, :params, :scope) do
      def self.public(locale: Nibble.config.default_locale.code, entry: nil, term: nil, set: nil, params: {}, now: Time.current)
        new(locale:, now:, entry:, term:, set:, params: params.to_h.stringify_keys, scope: :public)
      end

      def public? = scope == :public

      def resolve(value)
        case value
        when Array then value.flat_map { |item| Array.wrap(resolve(item)) }
        when String then value.start_with?("$") ? variable(value.delete_prefix("$")) : value
        else value
        end
      end

      private

      def variable(path)
        name, *rest = path.split(".")
        root = case name
        when "now" then now
        when "locale" then locale
        when "params" then params
        when "entry" then entry
        when "term" then term
        when "set" then set
        else raise Invalid.new("$#{name}", "isn't a query variable")
        end
        rest.empty? ? identity(root) : dig(root, rest)
      end

      def identity(value) = value.respond_to?(:record_type) ? value.id : value

      def dig(root, keys)
        keys.reduce(root) do |current, key|
          case current
          when nil then nil
          when Hash then current[key]
          else
            current.respond_to?(:values) && current.values.key?(key) ? current.values[key] : (current.has_attribute?(key) ? current[key] : nil)
          end
        end
      end
    end
  end
end
