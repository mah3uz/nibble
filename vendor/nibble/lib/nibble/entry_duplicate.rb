module Nibble
  class EntryDuplicate
    CARRIED_COLUMNS = %w[slug parent_id template].freeze
    ROW_KEYS = [ Fieldtypes::HasSets::ROW_ID, "_id" ].freeze

    def self.call(entry, actor:) = new(entry).call(actor)

    def initialize(entry) = @entry = entry

    def call(actor)
      copy = Records::Entry.new(collection: @entry.collection, blueprint: @entry.blueprint, locale: @entry.locale)
      Lifecycle.call(copy, :create, attrs, actor:)
    end

    private

    def attrs
      source = (@entry.draft&.data || @entry.snapshot).stringify_keys
      values = copied(@entry.blueprint_fields, source).merge(source.slice(*CARRIED_COLUMNS))
      values["title"] = "#{@entry.title} (copy)"
      values["slug"] = unique_slug(values["slug"]) if values["slug"].present?
      values
    end

    def copied(fields, values)
      fields.all.each_with_object({}) do |(handle, field), copy|
        next unless values.key?(handle)
        next copy.store(handle, field.default_value) unless field.duplicate?

        copy[handle] = fresh_rows(field, values[handle])
      end.compact
    end

    def fresh_rows(field, value)
      return value unless value.is_a?(Array) && (field.type == "grid" || field.fieldtype.is_a?(Fieldtypes::HasSets))

      value.each_with_index.map do |row, index|
        next row unless row.is_a?(Hash)

        row = row.stringify_keys.except(*ROW_KEYS)
        fields = field.type == "grid" ? field.fieldtype.row_fields(index) : set_fields(field, row, index)
        fields ? row.merge(copied(fields, row)) : row
      end
    end

    def set_fields(field, row, index)
      field.fieldtype.set_fields(row["type"], index) if field.fieldtype.sets_config.key?(row["type"].to_s)
    end

    def unique_slug(slug)
      taken = Records::Entry.kept.where(collection: @entry.collection, locale: @entry.locale,
        parent_id: @entry.structured? ? @entry.parent_id : nil).pluck(:slug)
      candidate = "#{slug}-copy"
      number = 1
      candidate = "#{slug}-copy-#{number += 1}" while taken.include?(candidate)
      candidate
    end
  end
end
