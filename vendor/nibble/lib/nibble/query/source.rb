module Nibble
  class Query
    Source = Data.define(:kind, :handle) do
      ENTRY_COLUMNS = %w[id uuid blueprint locale title slug uri status published_at unpublish_at parent_id position template author_id created_at updated_at].freeze
      TERM_COLUMNS = %w[id uuid blueprint locale title slug uri created_at updated_at].freeze

      def self.parse(value, schema)
        kind, handle = value.to_s.split(":", 2)
        case kind
        when "entries"
          schema.collection(handle) or raise Invalid.new("from", "no collection '#{handle}'")
        when "terms"
          schema.taxonomy(handle) or raise Invalid.new("from", "no taxonomy '#{handle}'")
        when "search"
          Nibble::Search.indexes(schema:).key?(handle) or raise Invalid.new("from", "no search index '#{handle}'")
        when "form"
          schema.find(:forms, handle) or raise Invalid.new("from", "no form '#{handle}'")
        when "assets"
          raise Invalid.new("from", "'assets' sources aren't available yet")
        else
          raise Invalid.new("from", "must be entries:<collection>, terms:<taxonomy>, search:<index> or form:<handle>")
        end
        new(kind:, handle:)
      end

      def entries? = kind == "entries"
      def search? = kind == "search"
      def form? = kind == "form"
      def model = entries? ? Records::Entry : Records::Term
      def record_type = entries? ? "entry" : "term"
      def scope_column = entries? ? :collection : :taxonomy
      def columns = entries? ? ENTRY_COLUMNS : TERM_COLUMNS
      def tag = search? ? "search:#{handle}" : "#{entries? ? 'collection' : 'taxonomy'}:#{handle}"
      def schema_item(schema) = entries? ? schema.collection(handle) : schema.taxonomy(handle)

      def fields(schema)
        return {} if search? || form?

        schema.blueprints_for(schema_item(schema)).map { |item| Blueprint.new(item, schema:).fields }
          .flat_map { |fields| fields.all.values }.uniq(&:handle).index_by(&:handle)
      end

      def relation_fields(schema) = search? || form? ? {} : fields(schema).select { |_, field| field.fieldtype_class.relationship }
    end
  end
end
