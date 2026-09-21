module Nibble
  module Packages
    # A folder of Markdown files, read as the documents Importer already knows how to write.
    class MarkdownReader
      DEFAULT_FIELD = "body".freeze
      ROOT_SLUG = "home".freeze
      # A link to another page, written as a path between files, which only means something once both are pages.
      LINK = /(\]\()(?!\w+:|\/)([^)\s#]+\.md)(#[^)\s]*)?(\))/
      IMAGE = /(!\[[^\]]*\]\()(?!\w+:|\/)([^)\s]+)(\))/

      attr_reader :errors

      def initialize(root, collection:, field: DEFAULT_FIELD, locale: nil, images: {}, navigation: nil)
        @root = Pathname(root)
        @collection = collection
        @field = field || DEFAULT_FIELD
        @locale = locale || Nibble.config.default_locale.code
        @images = images
        @navigation = navigation
        @order = {}
        @errors = []
      end

      def documents
        raise Error, "#{@root} isn't a folder of Markdown" unless @root.directory?

        pages = Dir.glob("**/*.md", base: @root).sort.filter_map { |relative| document(relative) }
        @navigation ? pages + [ navigation(pages) ] : pages
      end

      # The folders are the tree a sidebar needs; order in the frontmatter says what comes first.
      def navigation(pages)
        by_parent = pages.group_by(&:parent_key)
        Document.new(kind: "navigation", handle: @navigation, locale: @locale,
                     key: @navigation, data: { "tree" => branch(by_parent, nil) }, file: "#{@navigation} navigation")
      end

      def branch(by_parent, key)
        Array(by_parent[key]).sort_by { |doc| [ @order[doc.key] || Float::INFINITY, doc.data["title"].to_s ] }
          .map do |doc|
            children = branch(by_parent, doc.key)
            children.any? ? { "entry" => doc.key, "children" => children } : { "entry" => doc.key }
          end
      end

      def redirects = []

      def assets = []

      private

      def document(relative)
        slugs = key_for(relative)
        parent = slugs[0..-2]
        if parent.any? && !@root.join(*parent, "index.md").file?
          return error(relative, "#{parent.join('/')}/ has no index.md, so #{slugs.last} has no page to sit under")
        end

        text = @root.join(relative).read
        front = Markdown.front_matter(text)
        key = [ @collection, *slugs ].join("/")
        # Where a page sits in the tree, which is Nibble's to know rather than a field of the blueprint.
        @order[key] = front.delete("order")
        data = front.merge(@field => rewrite(body(text), relative))
        Document.new(kind: "collections", handle: @collection, locale: @locale, key:, data:, file: relative)
      end

      # At the root there is no slug left, so the page is the collection's own root entry.
      def key_for(relative)
        parts = relative.delete_suffix(".md").split("/")
        parts = parts[0..-2] if parts.last == "index"
        parts.presence || [ ROOT_SLUG ]
      end

      def body(text) = text.sub(/\A---\n.*?\n---\n/m, "").strip

      # Both are rewritten to references, so a page keeps its link when the page or the file it points at moves.
      def rewrite(text, relative)
        link_pages(image_assets(text, relative), relative)
      end

      def image_assets(text, relative)
        here = Pathname(relative).dirname
        text.gsub(IMAGE) do
          open_bracket, target, close = Regexp.last_match.captures
          id = @images[here.join(target).cleanpath.to_s]
          id ? "#{open_bracket}nibble://asset/#{id}#{close}" : Regexp.last_match(0)
        end
      end

      def link_pages(text, relative)
        here = Pathname(relative).dirname
        text.gsub(LINK) do
          open_bracket, target, anchor, close = Regexp.last_match.captures
          key = key_for(here.join(target).cleanpath.to_s)
          "#{open_bracket}nibble://page/#{[ @collection, *key ].join('/')}#{anchor}#{close}"
        end
      end

      def error(file, message)
        @errors << "#{file}: #{message}"
        nil
      end
    end
  end
end
