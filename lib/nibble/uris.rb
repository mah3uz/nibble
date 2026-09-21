module Nibble
  module Uris
    TOKEN = /\{(\w+)\}/

    class << self
      def for(record)
        route = record.route
        return nil if route.blank? || record.slug.blank?
        return normalize(Nibble.config.locale(record.locale)&.url_prefix) if record.respond_to?(:home?) && record.home?

        values = tokens(record)
        path = route.gsub(TOKEN) { values.fetch(Regexp.last_match(1)) { return nil } || (return nil) }
        normalize(path)
      end

      def normalize(path) = "/#{path.to_s.split('/').compact_blank.join('/')}"

      private

      # Carries its own leading separator, as parent_uri does, so a route reads "/docs{parent_slugs}/{slug}".
      def ancestor_slugs(parent)
        slugs = []
        while parent
          slugs.unshift(parent.slug)
          parent = parent.respond_to?(:parent) ? parent.parent : nil
        end
        slugs.compact.any? ? "/#{slugs.compact.join('/')}" : ""
      end

      def tokens(record)
        date = record.respond_to?(:published_at) ? record.published_at : nil
        parent = record.respond_to?(:parent) ? record.parent : nil
        {
          "slug" => record.slug,
          "parent_uri" => parent ? parent.uri : "",
          "parent_slugs" => ancestor_slugs(parent),
          "year" => date&.strftime("%Y"),
          "month" => date&.strftime("%m"),
          "locale" => Nibble.config.locale(record.locale)&.url_prefix.to_s
        }
      end
    end
  end
end
