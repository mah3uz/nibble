module Nibble
  module Options
    class Content
      KEYS = %w[from where not sort limit value label parent].freeze
      QUERY_KEYS = %w[from where not sort].freeze
      LIMIT = 200
      SCALAR_TYPES = %w[text textarea slug integer decimal range rating color date time].freeze

      attr_reader :field, :raw

      def initialize(field, fields = nil)
        @field = field
        @fields = fields
        @raw = field.get("options")
        @records = {}
        @options = {}
      end

      def content? = true
      def localized_labels = []

      def value_key = raw.fetch("value", "slug").to_s
      def label_key = raw.fetch("label", "title").to_s
      def limit = raw["limit"].is_a?(Integer) ? raw["limit"].clamp(1, LIMIT) : LIMIT
      def parent_handle = (raw["parent"].is_a?(Hash) ? raw["parent"]["field"] : raw["parent"])&.to_s.presence
      def by = raw["parent"].is_a?(Hash) ? raw["parent"]["by"]&.to_s.presence : nil

      def spec(schema = Nibble.schema) = @spec ||= Query::Spec.parse(raw.slice(*QUERY_KEYS), schema:)

      def options(locale = nil)
        code = locale_code(locale)
        Dependencies.add(spec.source.tag, parent_source&.spec&.source&.tag)
        @options[code] ||= build(code)
      end

      def records(locale = nil)
        code = locale_code(locale)
        @records[code] ||= Query.new(spec, Query::Context.public(locale: code)).relation.limit(limit).to_a
      end

      def read(record, key) = record.has_attribute?(key) ? record[key] : record.values[key]

      # The key of the field's message for a value that isn't one of the options or belongs to no chosen parent.
      def problem(value, root_values, locale)
        found = options(locale).index_by { |option| option["value"].to_s }
        chosen = Array.wrap(value).map(&:to_s)
        return "in" unless chosen.all? { |item| found.key?(item) }
        return unless parent_handle

        answers = Array.wrap(root_values.to_h[parent_handle]).map(&:to_s)
        "in" unless chosen.all? { |item| found[item].fetch("parents", []).map(&:to_s).intersect?(answers) }
      end

      def problems(schema)
        problems = (raw.keys - KEYS).map { |key| "options.#{key} isn't an options key; use #{KEYS.join(', ')}" }
        source = begin
          spec(schema).source
        rescue Query::Invalid => error
          return problems << "options.#{error.message}"
        end
        if source.entries? && Files.collections(schema).any? { |item| item.handle == source.handle }
          return problems << "options.from names a collection kept as files, which can't give options"
        end

        problems << "options.limit must be a whole number from 1 to #{LIMIT}" unless raw["limit"].nil? || (raw["limit"].is_a?(Integer) && raw["limit"].between?(1, LIMIT))
        %w[value label].each { |key| problems << "options.#{key} must name a column or a field" unless raw[key].nil? || raw[key].is_a?(String) }
        [ value_key, label_key ].uniq.each do |handle|
          next if scalar?(source, handle, schema)

          problems << "options names '#{handle}', which isn't a column or a single-value field of #{source.kind}:#{source.handle}"
        end
        problems.concat(parent_problems(source, schema))
      end

      protected

      def parent_source
        return @parent_source if defined?(@parent_source)

        other = parent_handle && @fields&.get(parent_handle)
        source = other && Options.for(other, @fields)
        @parent_source = source.is_a?(Content) ? source : nil
      end

      private

      def locale_code(locale) = Nibble.config.locale(locale)&.code || Nibble.config.default_locale.code

      def build(code)
        parents = parent_handle && parents_of(code)
        options = {}
        records(code).each do |record|
          value = read(record, value_key)
          next unless scalar_value?(value) && value.to_s != ""

          label = read(record, label_key)
          option = options[value.to_s] ||= { "value" => value, "label" => (scalar_value?(label) && label.to_s.presence || value).to_s }
          option["parents"] = (option.fetch("parents", []) + parents.fetch(record.id, [])).uniq if parents
        end
        options.values
      end

      def parents_of(code)
        return {} unless parent_source

        values = parent_source.records(code).to_h { |record| [ record.id, parent_source.read(record, parent_source.value_key) ] }
        links(code, parent_source.spec.source).each_with_object({}) do |(id, parent_id), found|
          (found[id] ||= []) << values[parent_id] if values.key?(parent_id)
        end
      end

      def links(code, parent)
        ids = records(code).map(&:id)
        return records(code).filter_map { |record| [ record.id, record.parent_id ] if record.parent_id } unless by

        Records::Relation.where(source_type: spec.source.record_type, source_id: ids, field: by, target_type: parent.record_type).pluck(:source_id, :target_id)
      end

      def scalar_value?(value) = value.is_a?(String) || value.is_a?(Numeric)

      def scalar?(source, handle, schema)
        return true if source.columns.include?(handle)

        found = source.fields(schema)[handle]
        found.present? && SCALAR_TYPES.include?(found.type)
      end

      def parent_problems(source, schema)
        return [] if raw["parent"].nil?
        unless parent_handle && (raw["parent"].is_a?(String) || (raw["parent"].is_a?(Hash) && (raw["parent"].keys - %w[field by]).empty?))
          return [ "options.parent must name a field, or be a map with `field` and `by`" ]
        end

        return [ "options.parent names '#{parent_handle}', which isn't another choice field of this form with options from content" ] unless parent_source
        return [ "options.parent goes round in a circle: #{circle.join(' → ')}" ] if circle

        parent = begin
          parent_source.spec(schema).source
        rescue Query::Invalid
          return []
        end
        by ? by_problems(source, parent, schema) : tree_problems(source, parent, schema)
      end

      def tree_problems(source, parent, schema)
        unless source.entries? && parent == source && schema.collection(source.handle)["structure"].is_a?(Hash)
          return [ "options.parent '#{parent_handle}' must take options from the same structured collection to follow the tree; give `by` to follow a relationship instead" ]
        end

        []
      end

      def by_problems(source, parent, schema)
        relation = source.relation_fields(schema)[by]
        type, list = parent.entries? ? %w[entries collections] : %w[terms taxonomies]
        allowed = relation && Array(relation.get(list)).compact_blank
        return [] if relation&.type == type && (allowed.empty? || allowed.include?(parent.handle))

        [ "options.parent.by '#{by}' must be a #{type} field of #{source.kind}:#{source.handle} that can point at #{parent.kind}:#{parent.handle}" ]
      end

      def circle
        chain = [ field.handle ]
        current = parent_source
        while current
          return [ *chain, current.field.handle ] if chain.include?(current.field.handle)

          chain << current.field.handle
          current = current.parent_source
        end
        nil
      end
    end
  end
end
