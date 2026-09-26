module Nibble
  module Fieldtypes
    module HasSets
      ROW_ID = "id".freeze

      def self.generate_id = SecureRandom.alphanumeric(8)

      # A row id is bookkeeping the Control Plane follows a row by, not content, so a file carries none. Keep
      # the ids already stored, by position, or every import would mint new ones and never look unchanged.
      def self.carry_ids(stored, incoming)
        stored = Array(stored)
        Array(incoming).each_with_index.map do |row, index|
          row = row.to_h.stringify_keys
          next row if row[ROW_ID].present?

          id = stored[index].to_h.stringify_keys[ROW_ID]
          id.present? ? row.merge(ROW_ID => id) : row
        end
      end

      # Accepts grouped sets ({ group => { sets: { handle => set } } }) and the flat form ({ handle => set }).
      def sets_config
        sets = config("sets").to_h.deep_stringify_keys
        return {} if sets.empty?

        grouped = sets.values.first.is_a?(Hash) && sets.values.first.key?("sets")
        grouped ? sets.values.map { |group| group["sets"].to_h }.reduce({}, :merge) : sets
      end

      def sets? = sets_config.any?

      def nested_fields = sets_config.keys.map { |handle| set_fields(handle) }

      def publish_config(config)
        config.merge("sets" => publish_set_groups)
      end

      def publish_set_groups
        raw = config("sets").to_h.deep_stringify_keys
        grouped = raw.values.first.is_a?(Hash) && raw.values.first.key?("sets")
        groups = grouped ? raw : { "main" => { "display" => nil, "sets" => raw } }
        groups.map do |group_handle, group|
          { "handle" => group_handle, "display" => group["display"], "instructions" => group["instructions"], "icon" => group["icon"],
            "sets" => group["sets"].to_h.map do |set_handle, set|
              { "handle" => set_handle, "display" => set["display"] || set_handle.humanize, "instructions" => set["instructions"],
                "icon" => set["icon"], "fields" => set_fields(set_handle).to_publish_a }
            end }
        end
      end

      def set_fields(set_handle, index = -1)
        definitions = sets_config.dig(set_handle.to_s, "fields")
        Fields.new(definitions, schema: field&.schema, source: "#{field&.handle} set #{set_handle}", key: "sets.#{set_handle}.fields",
          parent_field: field, parent_index: index)
      end

      def set_preload(rows)
        existing = rows.to_h { |row| [ row[:id], set_fields(row[:type], row[:index]).add_values(row[:values]).meta ] }
        defaults = sets_config.keys.index_with { |handle| set_fields(handle).pre_process.values }
        {
          "existing" => existing,
          "new" => sets_config.keys.index_with { |handle| set_fields(handle).add_values(defaults[handle]).meta },
          "defaults" => defaults,
          "collapsed" => config("collapse") == true ? existing.keys : []
        }
      end

      def set_extra_rules(rows, root_values:, prefix:, replacements:)
        rows.reduce({}) do |rules, row|
          row_prefix = "#{prefix}#{row_path(row[:index])}."
          rules.merge(Validator.collect_rules(set_fields(row[:type], row[:index]), row[:values], root_values:, prefix: row_prefix, replacements:))
        end
      end

      def relations(value) = nested_set_values(value, :relations)
      def import_sets(value, ctx) = transfer_sets(value, ctx, :import)

      def transfer_sets(value, ctx, direction)
        rows = set_value_rows(value)
        transferred = rows.to_h do |row|
          fields = sets_config.dig(row[:type].to_s, "fields") ? set_fields(row[:type], row[:index]) : nil
          values = if fields
            row[:values].merge(fields.all.to_h { |handle, field| [ handle, field.fieldtype.public_send(direction, row[:values][handle], ctx) ] }.compact)
          else
            row[:values]
          end
          [ row[:index], values ]
        end
        [ rows, transferred ]
      end

      def set_search_text(value) = nested_set_values(value, :search_text).compact_blank.join(" ").presence
      def dependencies(value) = nested_set_values(value, :dependencies)

      def nested_set_values(value, method)
        set_value_rows(value).flat_map do |row|
          next [] unless sets_config.dig(row[:type].to_s, "fields")

          set_fields(row[:type], row[:index]).add_values(row[:values]).flat_map { |nested| nested.fieldtype.public_send(method, nested.value) }
        end
      end

      def set_max_rules
        max = config("max_sets").to_i
        max.positive? ? [ "max:#{max}" ] : []
      end

      def augment_set(type, id, values, index, shallow: false)
        return values.merge(ROW_ID => id, "type" => type) unless sets_config.dig(type, "fields")

        fields = set_fields(type, index).add_values(values)
        augmented = shallow ? fields.shallow_augment : fields.augment
        augmented.values.merge(ROW_ID => id, "type" => type)
      end
    end
  end
end
