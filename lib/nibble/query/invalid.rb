module Nibble
  class Query
    class Invalid < Error
      attr_reader :key

      def initialize(key, reason)
        @key = key
        super("#{key}: #{reason}")
      end
    end
  end
end
