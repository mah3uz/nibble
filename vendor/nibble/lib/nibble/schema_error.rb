module Nibble
  class SchemaError < Error
    attr_reader :file, :key, :reason

    # `key` is the dotted path inside the file, e.g. "tabs.main.sections.0.fields.2.field.type".
    def initialize(file:, reason:, key: nil)
      @file = file.to_s
      @key = key
      @reason = reason
      super([ @file.delete_prefix("#{Rails.root}/"), key, reason ].compact.join(": "))
    end
  end
end
