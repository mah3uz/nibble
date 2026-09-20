module Nibble
  class ConfigError < Error
    attr_reader :key, :reason

    def initialize(key, reason)
      @key = key
      @reason = reason
      super("config/nibble.yml: #{key}: #{reason}")
    end
  end
end
