module Nibble
  module Files
    TOKEN = /\{[a-z_]+\}/
    # Only means anything once both ends are pages, so it is resolved against the index rather than rewritten.
    LINK = /(\]\()(?!\w+:|\/)([^)\s#]+\.md)(#[^)\s]*)?(\))/

    class << self
      def collections(schema = Nibble.schema) = schema.all(:collections).select { |item| item["files"].present? }

      def declared?(schema = Nibble.schema) = collections(schema).any?

      def root_for(item) = Nibble.config.content_path.join(*item["files"].to_s.split("/"))

      # The folder shape is the address, so a route need not say where a nested page sits — the file already did.
      def uri_for(item, slugs)
        route = item["route"].to_s
        return Uris.normalize(route.gsub(TOKEN, "")) if slugs == [ Reader::ROOT_SLUG ]

        route = route.sub("/{slug}", "{parent_slugs}/{slug}") unless route.include?("{parent_slugs}")
        parents = slugs[0..-2]
        path = route.sub("{parent_slugs}", parents.any? ? "/#{parents.join('/')}" : "").sub("{slug}", slugs.last)
        Uris.normalize(path.gsub(TOKEN, ""))
      end

      def index = @index ||= Index.build

      def reload! = @index = Index.build

      def reset! = @index = nil

      # The folder is the content, so a change to it is a change to the site and must land between requests.
      def watch!
        @watcher ||= ActiveSupport::FileUpdateChecker.new([], Nibble.config.content_path.to_s => %w[md]) { reload! }
        @watcher.execute_if_updated
      end

      def body(path)
        rewrite(path.read.sub(/\A---\n.*?\n---\n/m, "").strip, path)
      end

      private

      def rewrite(body, path)
        body.gsub(LINK) do
          target = resolve(path, Regexp.last_match(2))
          target ? "#{Regexp.last_match(1)}#{target}#{Regexp.last_match(3)}#{Regexp.last_match(4)}" : Regexp.last_match(0)
        end
      end

      def resolve(path, relative)
        page = index.at_path(path.dirname.join(relative).cleanpath)
        page&.uri
      end
    end
  end
end
