module Nibble
  # Development-only harness for exercising every fieldtype in the CP before records exist.
  module Playground
    KITCHEN_SINK = Pathname(__dir__).join("playground/kitchen_sink.yml")

    Record = Data.define(:id, :title, :url, :status, :scope_key, :scope, :thumbnail, :alt)

    class DemoResolver
      def initialize(records, scope_key)
        @records = records.index_by(&:id)
        @scope_key = scope_key
      end

      def find(ids, scope: {}) = ids.filter_map { |id| (record = @records[id.to_s]) && in_scope?(record, scope) && summary(record) }

      def search(query:, scope: {}, limit: 20)
        @records.values.select { |record| in_scope?(record, scope) && record.title.downcase.include?(query.downcase) }.first(limit).map { |record| summary(record) }
      end

      def resolve(id) = (record = @records[id.to_s]) && { url: record.url, title: record.title }

      private

      def in_scope?(record, scope)
        allowed = Array(scope[@scope_key]).compact_blank
        allowed.empty? || allowed.include?(record.scope)
      end

      def summary(record)
        { "id" => record.id, "title" => record.title, "url" => record.url, "status" => record.status, "thumbnail" => record.thumbnail, "alt" => record.alt }.compact
      end
    end

    class << self
      def blueprints(schema = Nibble.schema)
        entries = { "kitchen_sink" => [ "Kitchen sink", kitchen_sink_item ] }
        (schema.collections + schema.taxonomies).each do |parent|
          schema.blueprints_for(parent).each { |item| entries["#{parent.handle}.#{item.handle}"] = [ "#{parent['title']}: #{item['title']}", item ] }
        end
        schema.globals.each do |item|
          inline = Schema::Item.new(kind: "blueprints", handle: item.handle, parent: item.key, path: item.path, layer: item.layer, data: item["blueprint"])
          entries["globals.#{item.handle}"] = [ "Globals: #{item['title']}", inline ]
        end
        entries
      end

      def kitchen_sink_item
        Schema::Item.new(kind: "blueprints", handle: "kitchen_sink", parent: "playground", path: KITCHEN_SINK, layer: :core,
          data: YAML.safe_load_file(KITCHEN_SINK).freeze)
      end

      def register_demo_resolvers
        image = ->(color) { "data:image/svg+xml,#{ERB::Util.url_encode(%(<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" fill="#{color}"/></svg>))}" }
        entries = DemoResolver.new([
          Record.new(id: "e1", title: "About us", url: "/about", status: "published", scope_key: "collections", scope: "pages", thumbnail: nil, alt: nil),
          Record.new(id: "e2", title: "Pricing", url: "/pricing", status: "draft", scope_key: "collections", scope: "pages", thumbnail: nil, alt: nil),
          Record.new(id: "e3", title: "Hello world", url: "/blog/hello-world", status: "published", scope_key: "collections", scope: "posts", thumbnail: nil, alt: nil)
        ], "collections")
        terms = DemoResolver.new(%w[Design Culture Everyday Travel].each_with_index.map do |title, index|
          Record.new(id: "t#{index + 1}", title:, url: "/topics/#{title.downcase}", status: nil, scope_key: "taxonomies", scope: "topics", thumbnail: nil, alt: nil)
        end, "taxonomies")
        assets = DemoResolver.new([ [ "a1", "Mountain", "#5b8def" ], [ "a2", "Forest", "#3fa66b" ], [ "a3", "Desert", "#e0a145" ] ].map do |id, title, color|
          Record.new(id:, title:, url: image.(color), status: nil, scope_key: "folder", scope: nil, thumbnail: image.(color), alt: "#{title} photo")
        end, "folder")

        { "entry" => entries, "term" => terms, "asset" => assets }.each { |type, resolver| Resolvers.register(type, resolver) }
        LinkTypes.register("entry", title: "Entry", resolver: entries)
        LinkTypes.register("term", title: "Term", resolver: terms)
      end
    end
  end
end
