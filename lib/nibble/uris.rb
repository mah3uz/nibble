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

      def tokens(record)
        date = record.respond_to?(:published_at) ? record.published_at : nil
        parent = record.respond_to?(:parent) ? record.parent : nil
        {
          "slug" => record.slug,
          "parent_uri" => parent ? parent.uri : "",
          "year" => date&.strftime("%Y"),
          "month" => date&.strftime("%m"),
          "locale" => Nibble.config.locale(record.locale)&.url_prefix.to_s
        }
      end
    end
  end
end
