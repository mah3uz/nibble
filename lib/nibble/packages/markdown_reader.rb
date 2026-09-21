module Nibble
  module Packages
    # A folder of Markdown files, read as the documents Importer already knows how to write.
    class MarkdownReader
      DEFAULT_FIELD = "body".freeze

      attr_reader :errors

      def initialize(root, collection:, field: DEFAULT_FIELD, locale: nil)
        @root = Pathname(root)
        @collection = collection
        @field = field || DEFAULT_FIELD
        @locale = locale || Nibble.config.default_locale.code
        @errors = []
      end

      def documents
        raise Error, "#{@root} isn't a folder of Markdown" unless @root.directory?

        Dir.glob("**/*.md", base: @root).sort.filter_map { |relative| document(relative) }
      end

      def redirects = []

      def assets = []

      private

      def document(relative)
        slugs = key_for(relative)
        return error(relative, "would have no slug — name it something other than index.md") if slugs.empty?

        parent = slugs[0..-2]
        if parent.any? && !@root.join(*parent, "index.md").file?
          return error(relative, "#{parent.join('/')}/ has no index.md, so #{slugs.last} has no page to sit under")
        end

        text = @root.join(relative).read
        data = Markdown.front_matter(text).merge(@field => body(text))
        Document.new(kind: "collections", handle: @collection, locale: @locale,
                     key: [ @collection, *slugs ].join("/"), data:, file: relative)
      end

      def key_for(relative)
        parts = relative.delete_suffix(".md").split("/")
        parts.last == "index" ? parts[0..-2] : parts
      end

      def body(text) = text.sub(/\A---\n.*?\n---\n/m, "").strip

      def error(file, message)
        @errors << "#{file}: #{message}"
        nil
      end
    end
  end
end
