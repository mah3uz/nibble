module Nibble
  # What a navigation menu's schema says about its items' fields, shared by the generated types and the agent schema.
  class MenuSchema
    BUILT_IN_KINDS = %w[link heading].freeze
    Kind = Data.define(:handle, :display, :link, :children, :fields)

    attr_reader :item

    def initialize(item, schema: Nibble.schema)
      @item = item
      @schema = schema
    end

    def handle = item.handle
    def item_fields = fields(item["item_fields"], "item_fields")
    def entry_fields = Array(item["entry_fields"]).map(&:to_s)
    def queries = Array(item["queries"]).map(&:to_s)

    def kinds
      @kinds ||= item["kinds"].to_h.map do |kind, config|
        config = config.to_h
        Kind.new(handle: kind.to_s, display: config["display"] || kind.to_s.humanize, link: config["link"] || "optional",
          children: config["children"] != false, fields: fields(config["fields"], "kinds.#{kind}.fields"))
      end
    end

    def kind_handles = [ *BUILT_IN_KINDS, *("query" if queries.any?), *kinds.map(&:handle) ].uniq

    def entry_field(handle)
      parents = Array(item["collections"]).filter_map { |collection| @schema.collection(collection) }
      parents.flat_map { |parent| @schema.blueprints_for(parent).filter_map { |blueprint| Blueprint.for(blueprint, schema: @schema).field(handle) } }
    end

    private

    def fields(items, key) = Fields.new(Array(items), schema: @schema, source: item.path, key:)
  end
end
