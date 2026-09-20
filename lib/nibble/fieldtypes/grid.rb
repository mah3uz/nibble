module Nibble
  module Fieldtypes
    class Grid < Fieldtype
      self.categories = %w[structured]
      self.contract_samples = [ [ { "id" => "row00001" } ] ]
      self.config_field_items = [
        { "display" => "Fields", "fields" => { "fields" => { "type" => "list", "default" => [] } } },
        { "display" => "Appearance", "fields" => {
          "mode" => { "type" => "select", "default" => "table", "options" => %w[table stacked], "width" => 50 },
          "add_row" => { "type" => "text", "width" => 50 },
          "reorderable" => { "type" => "toggle", "default" => true, "width" => 50 },
          "fullscreen" => { "type" => "toggle", "default" => true, "width" => 50 }
        } },
        { "display" => "Boundaries & Limits", "fields" => {
          "min_rows" => { "type" => "integer", "width" => 50 },
          "max_rows" => { "type" => "integer", "width" => 50 }
        } }
      ]

      def row_fields(index = -1)
        Fields.new(config("fields"), schema: field&.schema, source: "#{field&.handle} grid", key: "fields", parent_field: field, parent_index: index)
      end

      def nested_fields = [ row_fields ]
      def publish_config(config) = config.merge("fields" => row_fields.to_publish_a)

      def pre_process(value)
        Array(value).each_with_index.map do |row, index|
          row = row.to_h.stringify_keys
          row.except(HasSets::ROW_ID).merge(row_fields(index).add_values(row).pre_process.values)
            .merge("_id" => row[HasSets::ROW_ID] || row["_id"] || HasSets.generate_id)
        end
      end

      def process(value)
        Array(value).each_with_index.map do |row, index|
          row = row.to_h.stringify_keys
          { HasSets::ROW_ID => row["_id"] || row[HasSets::ROW_ID] || HasSets.generate_id }
            .merge(row.except("_id", HasSets::ROW_ID)).merge(row_fields(index).add_values(row).process.values).compact
        end
      end

      def pre_process_validatable(value)
        Array(value).each_with_index.map do |row, index|
          row.to_h.stringify_keys.merge(row_fields(index).add_values(row).pre_process_validatable.values)
        end
      end

      def rules
        [ "array", *("min:#{config('min_rows')}" if config("min_rows").to_i.positive?), *("max:#{config('max_rows')}" if config("max_rows").to_i.positive?) ]
      end

      def extra_rules(root_values: nil, prefix: "", replacements: {})
        Array(field&.value).each_with_index.reduce({}) do |rules, (row, index)|
          rules.merge(Validator.collect_rules(row_fields(index), row, root_values:, prefix: "#{prefix}#{index}.", replacements:))
        end
      end

      def preload
        defaults = row_fields.pre_process.values
        {
          "defaults" => defaults,
          "new" => row_fields.add_values(defaults).meta,
          "existing" => Array(field&.value).each_with_index.to_h do |row, index|
            row = row.to_h.stringify_keys
            [ row["_id"] || row[HasSets::ROW_ID], row_fields(index).add_values(row).meta ]
          end
        }
      end

      def augment(value) = Array(value).each_with_index.map { |row, index| augment_row(row, index, :augment) }
      def shallow_augment(value) = Array(value).each_with_index.map { |row, index| augment_row(row, index, :shallow_augment) }

      def relations(value) = nested_row_values(value, :relations)
      def dependencies(value) = nested_row_values(value, :dependencies)
      def import(value, ctx = nil) = transfer(value, ctx, :import)
      def export(value, ctx = nil) = transfer(value, ctx, :export)

      def transfer(value, ctx, direction)
        return value unless ctx

        Array(value).each_with_index.map do |row, index|
          row = row.to_h.stringify_keys
          row.merge(row_fields(index).all.to_h { |handle, field| [ handle, field.fieldtype.public_send(direction, row[handle], ctx) ] }.compact)
        end
      end

      def search_text(value) = nested_row_values(value, :search_text).compact_blank.join(" ").presence

      def ts_type = "Array<Record<string, unknown> & { id: string }>"

      private

      def nested_row_values(value, method)
        Array(value).each_with_index.flat_map do |row, index|
          row_fields(index).add_values(row.to_h.stringify_keys).flat_map { |nested| nested.fieldtype.public_send(method, nested.value) }
        end
      end

      def augment_row(row, index, method)
        row = row.to_h.stringify_keys
        row_fields(index).add_values(row).public_send(method).values.merge(HasSets::ROW_ID => row[HasSets::ROW_ID])
      end
    end
  end
end
