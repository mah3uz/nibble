module Nibble
  class Lifecycle
    # Rows are matched to stored rows by id, so a kept value moves with its row; a row without a stored id is new.
    class ReadOnly
      attr_reader :ignored

      def initialize = @ignored = []

      def keep(fields, values, before, root: nil, path: nil)
        values = values.to_h.stringify_keys.dup
        before = before.to_h.stringify_keys
        root ||= values
        always, others = fields.all.values.partition { |field| field.visibility == "read_only" }
        always.each { |field| restore(values, before, field, path) }
        locked, open = others.partition { |field| field.read_only?(values, root_values: root) }
        locked.each { |field| restore(values, before, field, path) }
        open.each do |field|
          next if !values.key?(field.handle) || values[field.handle] == before[field.handle]

          values[field.handle] = rows(field, values[field.handle], before[field.handle], root, join(path, field.handle))
        end
        values
      end

      private

      def restore(values, before, field, path)
        handle = field.handle
        return unless values.key?(handle) || before.key?(handle)
        return if values[handle] == before[handle]

        @ignored << join(path, handle) if values.key?(handle)
        before.key?(handle) ? values[handle] = before[handle] : values.delete(handle)
      end

      def rows(field, value, before, root, path)
        return value unless value.is_a?(Array) && (field.type == "grid" || field.fieldtype.is_a?(Fieldtypes::HasSets))

        stored = Array(before).select { |row| row.is_a?(Hash) }.map(&:stringify_keys).index_by { |row| row[Fieldtypes::HasSets::ROW_ID] }
        claimed = Set.new
        value.each_with_index.map do |row, index|
          next row unless row.is_a?(Hash)

          row = row.stringify_keys
          fields = row_fields(field, row, index) or next row
          id = (row["_id"] || row[Fieldtypes::HasSets::ROW_ID]).presence
          match = stored[id] if id && claimed.add?(id)
          match = nil if match && field.type != "grid" && match["type"] != row["type"]
          keep(fields, row, match || fields.defaults, root:, path: join(path, index))
        end
      end

      def row_fields(field, row, index)
        return field.fieldtype.row_fields(index) if field.type == "grid"

        field.fieldtype.set_fields(row["type"], index) if field.fieldtype.sets_config.key?(row["type"].to_s)
      end

      def join(path, key) = [ path, key ].compact.join(".")
    end
  end
end
