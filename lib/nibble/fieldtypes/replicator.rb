module Nibble
  module Fieldtypes
    class Replicator < Fieldtype
      include HasSets

      self.categories = %w[structured]
      self.contract_samples = [ [ { "id" => "set00001", "type" => "hero" } ] ]
      self.keywords = %w[builder page blocks sets]
      self.config_field_items = [
        { "display" => "Manage Sets", "fields" => { "sets" => { "type" => "list" } } },
        { "display" => "Appearance", "fields" => {
          "collapse" => { "type" => "select", "default" => false, "options" => [ false, true, "accordion" ], "width" => 50 },
          "previews" => { "type" => "toggle", "default" => true, "width" => 50 },
          "fullscreen" => { "type" => "toggle", "default" => true, "width" => 50 },
          "button_label" => { "type" => "text", "default" => "", "width" => 50 }
        } },
        { "display" => "Boundaries & Limits", "fields" => { "max_sets" => { "type" => "integer" } } }
      ]

      def pre_process(value)
        Array(value).each_with_index.map do |row, index|
          row = row.to_h.stringify_keys
          id = row.delete(ROW_ID) || row["_id"] || HasSets.generate_id
          row.merge(set_fields(row["type"], index).add_values(row).pre_process.values).merge("_id" => id, "enabled" => row["enabled"] != false)
        end
      end

      def process(value)
        Array(value).each_with_index.map do |row, index|
          row = row.to_h.stringify_keys
          id = row.delete("_id") || row[ROW_ID] || HasSets.generate_id
          processed = { ROW_ID => id }.merge(row.except(ROW_ID)).merge(set_fields(row["type"], index).add_values(row).process.values)
          processed.delete("enabled") if processed["enabled"] == true
          processed.compact
        end
      end

      def pre_process_validatable(value)
        Array(value).each_with_index.map do |row, index|
          row = row.to_h.stringify_keys
          row.merge(set_fields(row["type"], index).add_values(row).pre_process_validatable.values)
        end
      end

      def rules = [ "array", *set_max_rules ]

      def extra_rules(root_values: nil, prefix: "", replacements: {})
        set_extra_rules(rows(field&.value), root_values:, prefix:, replacements:)
      end

      def preload = set_preload(rows(field&.value))

      def augment(value, shallow: false)
        Array(value).each_with_index.filter_map do |row, index|
          row = row.to_h.stringify_keys
          next if row["enabled"] == false

          augment_set(row["type"], row[ROW_ID], row.except(ROW_ID, "type", "enabled"), index, shallow:)
        end
      end

      def shallow_augment(value) = augment(value, shallow: true)
      def search_text(value) = set_search_text(value)

      def import(value, ctx = nil) = transfer(value, ctx, :import)
      def export(value, ctx = nil) = transfer(value, ctx, :export)

      def transfer(value, ctx, direction)
        return value unless ctx

        _, transferred = transfer_sets(value, ctx, direction)
        Array(value).each_with_index.map { |_, index| transferred[index] }
      end

      def ts_type = "Array<{ id: string; type: string } & Record<string, unknown>>"

      private

      def row_path(index) = index.to_s

      def set_value_rows(value) = rows(value)

      def rows(value)
        Array(value).each_with_index.map do |row, index|
          row = row.to_h.stringify_keys
          { id: row["_id"] || row[ROW_ID], type: row["type"], values: row, index: }
        end
      end
    end
  end
end
