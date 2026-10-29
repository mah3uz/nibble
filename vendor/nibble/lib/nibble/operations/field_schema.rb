module Nibble
  module Operations
    # The JSON Schema an app writes a field's value against. A fieldtype from an extension can define its own.
    module FieldSchema
      HIDDEN = %w[secret note].freeze
      IDS = { "type" => "array", "items" => { "type" => "string" }, "description" => "IDs of the records it links to" }.freeze
      TYPES = {
        "text" => { "type" => "string" },
        "textarea" => { "type" => "string" },
        "code" => { "type" => "string", "description" => "HTML" },
        "slug" => { "type" => "string", "pattern" => "^[a-z0-9]+(?:-[a-z0-9]+)*$" },
        "markdown" => { "type" => "string", "description" => "Markdown" },
        "rich_text" => { "type" => [ "string", "array" ],
                         "description" => "Markdown, at any depth, inside sets too. Images as ![alt](asset:ID). Content Markdown can't hold comes back as editor JSON (an array of nodes), which is accepted as it is." },
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

      MAX_DEPTH = 3

      module_function

      FORMATS = { "email" => "email", "url" => "uri" }.freeze
      OPERATORS = { "equals" => "is", "===" => "is", "not" => "is not", "!==" => "is not", "contains" => "contains",
                    "contains_any" => "contains any of", ">" => "is more than", ">=" => "is at least", "<" => "is less than",
                    "<=" => "is at most" }.freeze

      def for(field, depth = 0)
        return nil if HIDDEN.include?(field.type)

        own = field.fieldtype.respond_to?(:json_schema)
        schema = own ? field.fieldtype.json_schema : (TYPES[field.type] || choice(field))
        return nil unless schema

        schema = nested(field, rules(field, schema), depth) unless own
        schema = schema.merge("title" => field.display)
        schema = schema.merge("readOnly" => true) if field.visibility == "read_only"
        notes = [ field.instructions.presence, schema["description"], *labels(field), *conditions(field) ].compact
        notes.any? ? schema.merge("description" => notes.join(" — ")) : schema
      end

      def rules(field, schema)
        limit = field.get("character_limit").to_i
        schema = schema.merge("maxLength" => limit) if limit.positive? && %w[text textarea markdown].include?(field.type)
        case field.type
        when "text" then FORMATS[field.get("input_type")] ? schema.merge("format" => FORMATS[field.get("input_type")]) : schema
        when "integer" then integer(field, schema)
        when "date"
          time = field.get("time_enabled") == true
          schema.merge("format" => time ? "date-time" : "date", "description" => time ? "ISO 8601 date-time" : "ISO 8601 date")
        else schema
        end
      end

      def integer(field, schema)
        min, max, step = field.get("min"), field.get("max"), field.get("step").to_i
        schema = schema.merge({ "minimum" => min, "maximum" => max }.compact)
        return schema unless step.positive?

        (min.to_i % step).zero? ? schema.merge("multipleOf" => step) : schema.merge("description" => "In steps of #{step} from #{min}")
      end

      def labels(field)
        return [] unless %w[select radio checkboxes button_group].include?(field.type) && field.fieldtype.respond_to?(:options)

        options = field.fieldtype.options
        return [] if options.all? { |option| option["label"].to_s == option["value"].to_s }

        [ "Options: #{options.map { |option| "#{option['value']} (#{option['label']})" }.join(', ')}" ]
      end

      def conditions(field)
        shown = Conditions.describe(field.config, prefix: field.prefix)
        locked = field.read_only_condition && Conditions.describe(field.read_only_condition, prefix: field.prefix)
        [ (shown && "#{shown['show'] ? 'Only when' : 'Not when'} #{sentence(shown)}; otherwise it isn't saved"),
          (locked && "Read-only #{locked['show'] ? 'when' : 'unless'} #{sentence(locked)}; a value sent then is ignored") ].compact
      end

      def sentence(described)
        described["rules"].map do |rule|
          next "the custom condition #{rule['value'].to_s.delete_prefix('custom ')} passes" if rule["operator"] == "custom"

          value = { "null" => "empty", "empty" => "empty" }.fetch(rule["value"], rule["value"])
          "#{rule['field'].to_s.sub(Conditions::ROOT_PREFIX, '')} #{OPERATORS.fetch(rule['operator'], rule['operator'])} #{value}"
        end.join(described["match"] == "any" ? " or " : " and ")
      end

      def conditional?(field) = Conditions.describe(field.config, prefix: field.prefix).present?

      def nested(field, schema, depth)
        return schema if depth >= MAX_DEPTH

        if field.type == "replicator" && field.fieldtype.sets_config.any?
          sets = field.fieldtype.sets_config.map do |handle, set|
            row = object(field.fieldtype.set_fields(handle), depth + 1)
            row.merge("title" => set["display"] || handle.humanize, "properties" => { "type" => { "const" => handle } }.merge(row["properties"]),
              "required" => [ "type", *row["required"] ])
          end
          schema.merge("items" => { "oneOf" => sets })
        elsif field.type == "grid" && field.get("fields").present?
          schema.merge("items" => object(field.fieldtype.row_fields, depth + 1))
        else
          schema
        end
      end

      def known?(field) = HIDDEN.include?(field.type) || field.fieldtype.respond_to?(:json_schema) || TYPES.key?(field.type) || choice(field).present?

      def choice(field)
        options = field.get("options")
        values = options.is_a?(Hash) ? options.keys : Array(options).map { |option| option.is_a?(Hash) ? option["key"] || option["value"] : option }
        return nil unless %w[select radio checkboxes button_group].include?(field.type)

        one = { "type" => "string", "enum" => values.map(&:to_s).presence }.compact
        field.type == "checkboxes" || field.get("multiple") == true ? { "type" => "array", "items" => one } : one
      end

      def object(fields, depth = 0)
        properties = fields.all.values.filter_map { |field| (schema = self.for(field, depth)) && [ field.handle, schema ] }.to_h
        required = fields.all.values.select { |field| field.required? && properties.key?(field.handle) && !conditional?(field) }.map(&:handle)
        { "type" => "object", "properties" => properties, "required" => required.presence }.compact
      end
    end
  end
end
