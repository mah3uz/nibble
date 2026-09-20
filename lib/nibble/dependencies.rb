module Nibble
  module Dependencies
    class << self
      def track
        previous = Thread.current[:nibble_dependencies]
        Thread.current[:nibble_dependencies] = Set.new
        result = yield
        [ result, Thread.current[:nibble_dependencies].to_a ]
      ensure
        Thread.current[:nibble_dependencies] = previous&.merge(Thread.current[:nibble_dependencies]) || previous
      end

      def add(*tags) = Thread.current[:nibble_dependencies]&.merge(tags.flatten.compact)
    end
  end
end
