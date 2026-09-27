module Nibble
  module Operations
    # Records as an app reads and writes them: stored values, rich text as Markdown, secrets never shown.
    module Editable
      ENTRY_COLUMNS = %w[title slug published_at unpublish_at parent_id template author_id].freeze
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

      def outgoing(fields, values)
        values.to_h.each_with_object({}) do |(key, value), result|
          field = fields.get(key)
          next if field && FieldSchema::HIDDEN.include?(field.type)

          result[key] = field&.type == "rich_text" && value.present? ? (RichTextMarkdown.to_markdown(value) || value) : value
        end
      end

      def incoming(fields, data, columns: [])
        data = data.to_h.stringify_keys
        unknown = data.keys - fields.handles - columns
        if unknown.any?
          raise Failure.new("unknown_fields", "#{unknown.to_sentence} #{unknown.one? ? "isn't a field" : "aren't fields"} here",
            hint: "Fields you can write: #{(columns + fields.handles).uniq.sort.join(', ')}. describe_schema lists their types.")
        end

        data.to_h do |key, value|
          field = fields.get(key)
          raise Failure.new("forbidden", "#{key} can't be written by an app") if field && FieldSchema::HIDDEN.include?(field.type)

          [ key, field&.type == "rich_text" && value.is_a?(String) ? RichTextMarkdown.to_nodes(value) : value ]
        end
      end
    end
  end
end
