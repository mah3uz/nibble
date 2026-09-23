module Nibble
  module Fieldtypes
    class Relationship < Fieldtype
      self.categories = %w[relationship]
      self.relationship = true
      self.selectable = false

      def self.resolver_type = raise(NotImplementedError)

      def single? = config("max_items").to_i == 1

      def pre_process(value) = Array.wrap(value)

      def process(value)
        ids = Array.wrap(value).compact_blank
        return nil if ids.empty?

        single? ? ids.first : ids
      end

      def rules
        [ "array", *("max:#{config('max_items')}" if config("max_items").to_i.positive?), "records_exist:#{scope_param}" ]
      end

      def pre_process_validatable(value) = Array.wrap(value).compact_blank

      def preload
        { "data" => find(field&.value), "max_items" => config("max_items"), "mode" => config("mode"), "create" => config("create") }
      end

      def pre_process_index(value) = find(value).map { |item| item.slice("id", "title", "edit_url", "status") }

      def augment(value)
        items = find(value)
        single? ? items.first : items
      end

      def import(value, ctx = nil)
        return value unless ctx

        ids = Array.wrap(value).compact_blank.map { |key| ctx.resolve(self.class.resolver_type, key) }
        single? ? ids.first : ids
      end

      def export(value, ctx = nil)
        return value unless ctx

        keys = Array.wrap(value).compact_blank.filter_map { |id| ctx.resolve(self.class.resolver_type, id) }
        single? ? keys.first : keys
      end

      def relations(value) = Array.wrap(value).compact_blank.map { |id| [ self.class.resolver_type, id ] }
      def dependencies(value) = Array.wrap(value).compact_blank.map { |id| "#{self.class.resolver_type}:#{id}" }

      def scope = {}

      def scope_param
        [ self.class.resolver_type, *scope.filter_map { |key, value| "#{key}=#{Array(value).join(";")}" if Array(value).any? } ].join(",")
      end

      private

      def find(value)
        ids = Array.wrap(value).compact_blank
        ids.empty? ? [] : Resolvers.find(self.class.resolver_type).find(ids, scope:)
      end
    end
  end
end
