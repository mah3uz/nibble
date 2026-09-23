module Nibble
  module Uris
    TOKEN = /\{(\w+)\}/
    SETTLE_PASSES = 10
    SETTLE_SINCE = "0.15.0".freeze

    class << self
      def for(record)
        route = record.route
        return nil if route.blank? || record.slug.blank?

        values = tokens(record)
        # A folder's own page answers where the folder does: /docs/{slug} without a slug left is /docs.
        values = values.merge("slug" => "", "parent_slugs" => "", "parent_uri" => "") if record.respond_to?(:home?) && record.home?
        path = route.gsub(TOKEN) { values.fetch(Regexp.last_match(1)) { return nil } || (return nil) }
        normalize(path)
      end

      def normalize(path) = "/#{path.to_s.split('/').compact_blank.join('/')}"

      # An address is worked out when a record is saved, so a route changed in the schema leaves every record where it
      # was until someone saves it. Run on every upgrade, this moves them all, with a 301 from wherever a live one stood.
      # Repeated because a child reads its parent's address, and a parent may move in the same pass.
      def settle!(schema: Nibble.schema)
        return 0 unless Nibble.config.defaults_at_least?(SETTLE_SINCE)

        collections = schema.collections.reject { |item| item["files"].present? }.map(&:handle)
        taxonomies = schema.taxonomies.map(&:handle)
        moved = 0
        SETTLE_PASSES.times do
          changed = settle(Records::Entry.kept.where(collection: collections)) + settle(Records::Term.kept.where(taxonomy: taxonomies))
          moved += changed
          break if changed.zero?
        end
        moved
      end

      private

      def settle(scope)
        scope.find_each.count do |record|
          uri = self.for(record)
          next false if uri == record.uri

          previous = record.uri
          record.update_columns(uri:, updated_at: Time.current)
          Records::Redirect.record_move(previous, uri) if record.live?
          true
        end
      end

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
