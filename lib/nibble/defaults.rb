module Nibble
  module Defaults
    class << self
      def register(name, &resolver)
        resolvers[name.to_s] = resolver
      end

      def resolve(name)
        resolver = resolvers[name.to_s] or raise Error, "no computed default '#{name}' is registered"
        resolver.call
      end

      def reset! = @resolvers = nil

      private

      def resolvers = @resolvers ||= {}
    end
  end
end
