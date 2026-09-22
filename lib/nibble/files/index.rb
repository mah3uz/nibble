module Nibble
  module Files
    # Nothing here is authoritative, so a stale index is fixed by building another rather than repairing it.
    class Index
      attr_reader :pages, :problems

      def self.build(schema: Nibble.schema) = new(Files.collections(schema))

      def initialize(items = [])
        @problems = []
        @pages = items.flat_map { |item| read(item) }
        @by_uri = @pages.index_by(&:uri)
        @by_id = @pages.index_by(&:id)
        @by_collection = @pages.group_by(&:collection)
        @by_path = @pages.index_by { |page| page.path.to_s }
        detect_duplicates
      end

      def page(uri) = @by_uri[uri]
      def find(id) = @by_id[id]
      def of(collection) = @by_collection.fetch(collection, [])
      def any? = @pages.any?
      def ok? = @problems.empty?

      # A link is written between files and has to survive either of them moving, so it is resolved here.
      def at_path(path) = @by_path[path.to_s]

      # The collection's own page is the folder, not something sitting in it.
      def tree(collection)
        by_parent = of(collection).reject(&:root?).group_by(&:parent_key)
        branch(by_parent, nil)
      end

      private

      def read(item)
        reader = Reader.new(item)
        pages = reader.pages
        @problems.concat(reader.problems)
        pages
      end

      def branch(by_parent, key)
        Array(by_parent[key]).sort_by { |page| [ page.position || Float::INFINITY, page.title ] }.map do |page|
          children = branch(by_parent, page.key)
          link = { "entry" => page.key, "title" => page.title, "url" => page.uri }
          children.any? ? link.merge("children" => children) : link
        end
      end

      def detect_duplicates
        [ [ :uri, @pages.group_by(&:uri) ], [ :id, @pages.group_by(&:id) ] ].each do |name, grouped|
          grouped.each do |value, pages|
            next if pages.size < 2

            @problems << Reader::Problem.new(file: pages.map { |page| relative(page) }.join(", "),
                                             message: "share the same #{name} #{value.inspect}")
          end
        end
      end

      def relative(page) = page.path.relative_path_from(Rails.root).to_s
    end
  end
end
