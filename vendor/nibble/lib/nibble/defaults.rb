module Nibble
  module Defaults
    BUILT_IN = { "today" => -> { Time.zone.today.iso8601 } }.freeze

    class << self
      def register(name, &resolver)
        resolvers[name.to_s] = resolver
      end

      def resolve(name)
        resolver = resolvers[name.to_s] or raise Error, "no computed default '#{name}' is registered"
        resolver.call
      end

      def registered?(name) = resolvers.key?(name.to_s)

      def reset! = @resolvers = nil

      private

      def resolvers = @resolvers ||= BUILT_IN.dup
    end
  end
end
