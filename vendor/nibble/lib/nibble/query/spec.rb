module Nibble
  class Query
    class Spec
      KEYS = %w[from where not q locale sort paginate limit offset include fields counts].freeze
      COLUMN_OPERATORS = %w[eq ne in lt lte gt gte null prefix].freeze
      RELATION_OPERATORS = %w[in all none].freeze
      MAX_PER_PAGE = 100

      Condition = Data.define(:field, :operator, :value, :relation)
      Sort = Data.define(:column, :direction, :field)

      attr_reader :source, :conditions, :exclusions, :q, :locale, :sorts, :paginate, :limit, :offset, :include, :fields, :counts, :raw

      VARIABLE = /\A\$(set|entry)\.\w+\z/

      def self.parse(raw, schema: Nibble.schema, context: nil) = new(raw, schema, context)

      def initialize(raw, schema, context = nil)
        @raw = raw.to_h.deep_stringify_keys
        @schema = schema
        @context = context
        unknown = @raw.keys - KEYS
        raise Invalid.new(unknown.first, "isn't a query key") if unknown.any?
        raise Invalid.new("from", "is required") if @raw["from"].blank?

        @source = Source.parse(@raw["from"], schema)
        raise Invalid.new((@raw.keys - %w[from]).first, "isn't supported by form sources") if source.form? && @raw.keys != [ "from" ]
        @relation_fields = source.relation_fields(schema)
        @field_handles = source.fields(schema).keys
        @conditions = parse_conditions(@raw["where"], "where")
        @exclusions = parse_conditions(@raw["not"], "not")
        @q = @raw["q"]
        raise Invalid.new("q", "is only for search sources") if @q && !source.search?
        raise Invalid.new("q", "is required for search sources") if source.search? && @q.blank?
        %w[not sort include].each { |key| raise Invalid.new(key, "isn't supported by search sources") if source.search? && @raw.key?(key) }
        @conditions.each { |condition| raise Invalid.new("where.collection.#{condition.operator}", "isn't an operator (use eq, in)") unless %w[eq in].include?(condition.operator) } if source.search?
        @locale = @raw["locale"]
        @sorts = parse_sorts
        @paginate = parse_paginate
        @limit = bounded("limit", @raw["limit"])
        @offset = @raw["offset"].nil? ? nil : Integer(@raw["offset"], exception: false) || raise(Invalid.new("offset", "must be a number"))
        raise Invalid.new("paginate", "can't be combined with limit") if @paginate && @limit
        @counts = parse_counts
        @include = @raw["include"].nil? ? [] : parse_list("include") { |handle| @relation_fields.key?(handle) || raise(Invalid.new("include", "'#{handle}' isn't a relationship field")) }
        @fields = @raw.key?("fields") ? parse_list("fields") { |handle| valid_field?(handle) || raise(Invalid.new("fields", "unknown field '#{handle}'")) } : nil
      end

      def params = paginate ? [ paginate["param"] ] : []

      def column_fields_only? = !source.search? && fields && fields.all? { |handle| source.columns.include?(handle) || handle == "url" }

      private

      def valid_field?(handle) = source.search? || source.columns.include?(handle) || @field_handles.include?(handle) || %w[url parent].include?(handle)

      def parse_conditions(raw, key)
        return [] if raw.nil?
        raise Invalid.new(key, "must be a map of fields") unless raw.is_a?(Hash)

        raw.flat_map do |field, condition|
          relation = @relation_fields.key?(field)
          raise Invalid.new("#{key}.#{field}", "isn't filterable (only columns and relationship fields are)") unless relation || source.columns.include?(field)

          operators = condition.is_a?(Hash) ? condition : { (relation ? "in" : "eq") => condition }
          operators.map do |operator, value|
            allowed = relation ? RELATION_OPERATORS : COLUMN_OPERATORS
            raise Invalid.new("#{key}.#{field}.#{operator}", "isn't an operator (use #{allowed.join(', ')})") unless allowed.include?(operator)

            Condition.new(field:, operator:, value:, relation:)
          end
        end
      end

      def parse_sorts
        return [] if source.search? || source.form?

        raw = @raw["sort"] || source.schema_item(@schema)["sort"]
        Array(raw).map do |entry|
          column, direction = entry.to_s.split(":", 2)
          field = !source.columns.include?(column) && source.fields(@schema).key?(column)
          raise Invalid.new("sort", "'#{column}' isn't a sortable column or field") unless source.columns.include?(column) || field
          raise Invalid.new("sort", "direction must be asc or desc") unless [ nil, "asc", "desc" ].include?(direction)

          Sort.new(column:, direction: (direction || "asc").to_sym, field:)
        end
      end

      def parse_counts
        return nil unless @raw.key?("counts")
        raise Invalid.new("counts", "is only for terms sources") unless source.kind == "terms"

        handle = @raw["counts"].to_s
        @schema.collection(handle) ? handle : raise(Invalid.new("counts", "no collection '#{handle}'"))
      end

      def parse_paginate
        raw = @raw["paginate"] or return nil
        raw = { "per_page" => raw } if raw.is_a?(Integer)
        raise Invalid.new("paginate", "must be a map with per_page") unless raw.is_a?(Hash)

        raise Invalid.new("paginate.scroll", "must be true or false") unless [ nil, true, false ].include?(raw["scroll"])

        { "per_page" => bounded("paginate.per_page", raw["per_page"] || 12, fallback: 12), "param" => (raw["param"] || "page").to_s,
          "scroll" => raw["scroll"] == true }
      end

      def variable?(value) = value.is_a?(String) && value.start_with?("$")

      def bounded(key, value, fallback: MAX_PER_PAGE)
        return nil if value.nil?
        (value, fallback) = with_default(key, value, fallback) if value.is_a?(Hash)
        return variable_number(key, value, fallback) if variable?(value)

        number = Integer(value, exception: false)
        raise Invalid.new(key, "must be between 1 and #{MAX_PER_PAGE}") unless number && number.between?(1, MAX_PER_PAGE)

        number
      end

      def with_default(key, raw, fallback)
        raise Invalid.new(key, "takes from and default") unless (raw.keys - %w[from default]).empty? && variable?(raw["from"])
        return [ raw["from"], fallback ] unless raw.key?("default")

        default = Integer(raw["default"], exception: false)
        raise Invalid.new("#{key}.default", "must be between 1 and #{MAX_PER_PAGE}") unless default&.between?(1, MAX_PER_PAGE)

        [ raw["from"], default ]
      end

      def variable_number(key, value, fallback)
        raise Invalid.new(key, "variable must be $set.<field> or $entry.<field>") unless value.match?(VARIABLE)
        return fallback unless @context

        resolved = @context.resolve(value)
        number = Integer(resolved.to_s.strip, exception: false) || Float(resolved.to_s.strip, exception: false)&.round
        number ? number.clamp(1, MAX_PER_PAGE) : fallback
      end

      def parse_list(key, &check)
        list = @raw[key]
        list = list.split(",").map(&:strip) if list.is_a?(String)
        raise Invalid.new(key, "must be a list") unless list.is_a?(Array)

        list.map(&:to_s).each(&check)
      end
    end
  end
end
