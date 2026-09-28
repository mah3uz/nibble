module Nibble
  module Operations
    # The JSON Schema an app writes a field's value against. A fieldtype from an extension can define its own.
    module FieldSchema
      HIDDEN = %w[secret analytics_tags].freeze
      IDS = { "type" => "array", "items" => { "type" => "string" }, "description" => "IDs of the records it links to" }.freeze
      TYPES = {
        "text" => { "type" => "string" },
        "textarea" => { "type" => "string" },
        "code" => { "type" => "string", "description" => "HTML" },
        "slug" => { "type" => "string", "pattern" => "^[a-z0-9]+(?:-[a-z0-9]+)*$" },
        "markdown" => { "type" => "string", "description" => "Markdown" },
        "rich_text" => { "type" => [ "string", "array" ],
                         "description" => "Markdown. Images as ![alt](asset:ID). Content with sets is editor JSON (an array of nodes)." },
        "integer" => { "type" => "integer" },
        "toggle" => { "type" => "boolean" },
        "date" => { "type" => "string", "description" => "ISO 8601 date or date-time" },
        "link" => { "type" => "string", "description" => "A URL, or entry::ID for an entry on this site" },
        "list" => { "type" => "array", "items" => { "type" => "string" } },
        "entries" => IDS, "terms" => IDS, "assets" => IDS, "files" => IDS,
        "grid" => { "type" => "array", "items" => { "type" => "object" }, "description" => "Rows, each an object of the row's fields" },
        "replicator" => { "type" => "array", "items" => { "type" => "object" }, "description" => "Sets, each an object with its type and fields" },
        "seo" => { "type" => "object" }
      }.freeze

      module_function

      def for(field)
        return nil if HIDDEN.include?(field.type)

        schema = field.fieldtype.respond_to?(:json_schema) ? field.fieldtype.json_schema : (TYPES[field.type] || choice(field))
        return nil unless schema

        schema = schema.merge("title" => field.display)
        field.instructions.present? ? schema.merge("description" => [ field.instructions, schema["description"] ].compact.join(" — ")) : schema
      end

      def known?(field) = HIDDEN.include?(field.type) || field.fieldtype.respond_to?(:json_schema) || TYPES.key?(field.type) || choice(field).present?

      def choice(field)
        options = field.get("options")
        values = options.is_a?(Hash) ? options.keys : Array(options).map { |option| option.is_a?(Hash) ? option["key"] || option["value"] : option }
        return nil unless %w[select radio checkboxes].include?(field.type)

        one = { "type" => "string", "enum" => values.map(&:to_s).presence }.compact
        field.type == "checkboxes" || field.get("multiple") == true ? { "type" => "array", "items" => one } : one
      end

      def object(fields)
        properties = fields.all.values.filter_map { |field| (schema = self.for(field)) && [ field.handle, schema ] }.to_h
        required = fields.all.values.select { |field| field.required? && properties.key?(field.handle) }.map(&:handle)
        { "type" => "object", "properties" => properties, "required" => required.presence }.compact
      end
    end
  end
end
