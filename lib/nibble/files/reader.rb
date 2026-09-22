module Nibble
  module Files
    # Opens no database and writes nothing, so a build can run it to find out whether the content is sound.
    class Reader
      ROOT_SLUG = "home".freeze
      RESERVED = %w[title blueprint template published_at].freeze

      Problem = Data.define(:file, :message) do
        def to_s = "#{file}: #{message}"
      end

      attr_reader :problems

      def initialize(item)
        @item = item
        @collection = item.handle
        @root = Files.root_for(item)
        @locale = Nibble.config.default_locale.code
        @problems = []
      end

      def pages
        unless @root.directory?
          problem(@root.to_s, "is not a folder")
          return []
        end

        Dir.glob("**/*.md", base: @root).sort.filter_map { |relative| page(relative) }
      end

      private

      def page(relative)
        slugs = slugs_for(relative)
        return if orphaned?(relative, slugs)

        front = front_matter(relative) or return
        id = front["id"].presence or return problem(relative, "has no id: in its frontmatter")

        page = Page.new(id: id.to_s, collection: @collection, slugs:, uri: Files.uri_for(@item, slugs),
                        path: @root.join(relative), digest: digest(relative), position: front["order"],
                        data: front.except("id", "order"), locale: @locale)
        stray = page.data.keys - page.blueprint_fields.handles - RESERVED
        stray.any? ? problem(relative, "has no #{'field'.pluralize(stray.size)} #{stray.join(', ')} in the #{page.blueprint} blueprint") : page
      end

      # A page under a folder belongs to that folder's page, so a folder without one has nowhere to put it.
      def orphaned?(relative, slugs)
        parent = slugs[0..-2]
        return false if parent.empty? || @root.join(*parent, "index.md").file?

        problem(relative, "#{parent.join('/')}/ has no index.md, so #{slugs.last} has no page to sit under")
      end

      def front_matter(relative)
        Markdown.front_matter(@root.join(relative).read)
      rescue Psych::SyntaxError => error
        problem(relative, "has frontmatter that is not valid YAML: #{error.message}")
      end

      # A folder's own index.md is the folder, so at the root no slug is left and the page is the collection's.
      def slugs_for(relative)
        parts = relative.delete_suffix(".md").split("/")
        parts = parts[0..-2] if parts.last == "index"
        parts.presence || [ ROOT_SLUG ]
      end

      def digest(relative) = Digest::SHA256.hexdigest(@root.join(relative).read)

      def problem(file, message)
        @problems << Problem.new(file:, message:)
        nil
      end
    end
  end
end
