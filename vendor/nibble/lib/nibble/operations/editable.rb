module Nibble
  module Operations
    # Records as an app reads and writes them: stored values, rich text as Markdown, secrets never shown.
    module Editable
      ENTRY_COLUMNS = %w[title slug published_at unpublish_at parent_id template].freeze
      TERM_COLUMNS = %w[title slug].freeze

      module_function

      def entry(record, site:)
        values = record.draft&.data || record.snapshot
        {
          "id" => record.id, "uuid" => record.uuid, "collection" => record.collection, "blueprint" => record.blueprint,
          "locale" => record.locale, "title" => record.title, "uri" => record.uri, "url" => Presenter.url(record.uri),
          "status" => record.status, "editing" => record.draft ? "draft" : "entry",
          "workflow" => record.draft&.workflow_status, "lock_version" => record.lock_version,
          "published_at" => record.published_at&.utc&.iso8601, "updated_at" => record.updated_at&.utc&.iso8601,
          "trashed" => record.trashed?, "cp_url" => "#{site}/cp/collections/#{record.collection}/entries/#{record.id}/edit",
          "data" => outgoing(record.blueprint_fields, values.slice(*ENTRY_COLUMNS, *record.blueprint_fields.handles))
        }
      end

      def entry_summary(record)
        { "id" => record.id, "title" => record.title, "slug" => record.slug, "uri" => record.uri, "status" => record.status,
          "has_draft" => record.draft.present?, "locale" => record.locale, "blueprint" => record.blueprint,
          "updated_at" => record.updated_at&.utc&.iso8601 }
      end

      def term(record, site:)
        {
          "id" => record.id, "uuid" => record.uuid, "taxonomy" => record.taxonomy, "blueprint" => record.blueprint,
          "locale" => record.locale, "title" => record.title, "uri" => record.uri, "url" => Presenter.url(record.uri),
          "lock_version" => record.lock_version, "trashed" => record.trashed?,
          "cp_url" => "#{site}/cp/taxonomies/#{record.taxonomy}/terms/#{record.id}/edit",
          "data" => outgoing(record.blueprint_fields, record.snapshot.slice(*TERM_COLUMNS, *record.blueprint_fields.handles))
        }
      end

      def global(record)
        { "handle" => record.handle, "locale" => record.locale, "lock_version" => record.lock_version,
          "data" => outgoing(record.blueprint_fields, record.values) }
      end

      def outgoing(fields, values) = walk(fields, values, :outgoing, nil)

      def incoming(fields, data, columns: [])
        data = data.to_h.stringify_keys
        unknown = data.keys - fields.handles - columns
        if unknown.any?
          raise Failure.new("unknown_fields", "#{unknown.to_sentence} #{unknown.one? ? "isn't a field" : "aren't fields"} here",
            hint: "Fields you can write: #{(columns + fields.handles).uniq.sort.join(', ')}. describe_schema lists their types.")
        end

        data.each_key do |key|
          field = fields.get(key)
          raise Failure.new("forbidden", "#{key} can't be written by an app") if field && FieldSchema::HIDDEN.include?(field.type)
        end
        walk(fields, data, :incoming, nil)
      end

      def walk(fields, values, direction, path)
        values.to_h.each_with_object({}) do |(key, value), result|
          field = fields.get(key)
          next if direction == :outgoing && field && FieldSchema::HIDDEN.include?(field.type)

          result[key] = field ? convert(field, value, direction, [ path, key ].compact.join(".")) : value
        end
      end

      def convert(field, value, direction, path)
        case field.type
        when "rich_text" then rich_text(value, direction, path)
        when "replicator" then rows(value) { |row, index| set_row(field, row, direction, "#{path}.#{index}") }
        when "grid" then rows(value) { |row, index| walk(field.fieldtype.row_fields, row, direction, "#{path}.#{index}") }
        else value
        end
      end

      def rows(value)
        return value unless value.is_a?(Array)

        value.each_with_index.map { |row, index| row.is_a?(Hash) ? yield(row.stringify_keys, index) : row }
      end

      def set_row(field, row, direction, path)
        type = row["type"].to_s
        unless field.fieldtype.sets_config.key?(type)
          warn_about("#{path}: #{type.presence || 'no type'} isn't a set of #{field.handle}") if direction == :incoming
          return row
        end

        walk(field.fieldtype.set_fields(type), row, direction, path)
      end

      def rich_text(value, direction, path)
        if direction == :outgoing
          value.present? ? (RichTextMarkdown.to_markdown(value) || value) : value
        elsif value.is_a?(String)
          RichTextMarkdown.to_nodes(value).tap { |nodes| check_assets(image_ids(nodes), path) }
        else
          value
        end
      end

      def image_ids(nodes)
        Array(nodes).flat_map { |node| node.is_a?(Hash) ? [ node.dig("attrs", "asset").presence, *image_ids(node["content"]) ] : [] }.compact
      end

      def check_assets(ids, path)
        missing = Array(ids).map(&:to_s) - Records::Asset.kept.where(id: Array(ids)).pluck(:id).map(&:to_s)
        missing.each { |id| warn_about("#{path}: asset #{id} doesn't exist") }
        ids
      end

      def warn_about(message) = Thread.current[:nibble_warnings]&.push(message)
    end
  end
end
