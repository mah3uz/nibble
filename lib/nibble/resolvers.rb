module Nibble
  # Resolvers implement find(ids, scope:) and search(query:, scope:, limit:), both returning record summaries.
  module Resolvers
    class << self
      def register(type, resolver) = resolvers[type.to_s] = resolver
      def unregister(type) = resolvers.delete(type.to_s)

      def find(type)
        override(type) || resolvers[type.to_s] or raise Error, "no record resolver is registered for '#{type}'"
      end

      def with_overrides(overrides)
        previous = Thread.current[:nibble_resolver_overrides]
        Thread.current[:nibble_resolver_overrides] = (previous || {}).merge(overrides.transform_keys(&:to_s))
        yield
      ensure
        Thread.current[:nibble_resolver_overrides] = previous
      end

      def override(type) = Thread.current[:nibble_resolver_overrides]&.dig(type.to_s)

      # Fetches every [type, scope, id] a batch of records will ask for in one query per type and scope,
      # then answers those finds from memory while the block runs.
      def preloading(wanted, &)
        overrides = wanted.group_by(&:first).to_h do |type, requests|
          resolver = find(type)
          found = requests.group_by { |request| request[1] }.to_h do |scope, rows|
            ids = rows.map(&:last).map(&:to_s).uniq
            [ scope, resolver.find(ids, scope:).index_by { |summary| summary["id"].to_s }.merge(asked: ids.to_set) ]
          end
          [ type, Preloaded.new(resolver, found) ]
        end
        with_overrides(overrides, &)
      end

      private

      def resolvers = @resolvers ||= {}
    end

    class Preloaded
      def initialize(resolver, found)
        @resolver = resolver
        @found = found
      end

      def find(ids, scope: {})
        cache = @found[scope]
        keys = ids.map(&:to_s)
        return @resolver.find(ids, scope:) unless cache && keys.all? { |id| cache[:asked].include?(id) }

        keys.filter_map { |id| cache[id] }
      end

      def method_missing(name, ...) = @resolver.respond_to?(name) ? @resolver.public_send(name, ...) : super
      def respond_to_missing?(name, include_private = false) = @resolver.respond_to?(name, include_private) || super
    end
  end
end
