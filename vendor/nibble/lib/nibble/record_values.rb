module Nibble
  class RecordValues
    def initialize(record)
      @record = record
      @fields = record.blueprint_fields
    end

    def validate(values, full:)
      replacements = { "id" => @record.id.to_s, "locale" => @record.locale.to_s, "type" => @record.record_type }
      result = Validator.new(@fields, replacements:, skip_required: !full).validate(values)
      result.errors
    end

    def process(values)
      values = values.to_h.stringify_keys
      extra = values.except(*@fields.handles)
      extra.merge(@fields.add_values(values.slice(*@fields.handles)).process.values.compact)
    end

    def relations(values)
      values = values.to_h.stringify_keys
      @fields.add_values(values).flat_map do |field|
        field.fieldtype.relations(field.value).each_with_index.map { |(type, id), position| [ field.handle, type, id, position ] }
      end
    end
  end
end
