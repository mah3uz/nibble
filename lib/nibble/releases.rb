require "net/http"

module Nibble
  module Releases
    CACHE_KEY = "nibble:releases".freeze
    CACHE_FOR = 6.hours

    Published = Data.define(:version, :url, :notes)

    class << self
      def newer(current: VERSION, feed: Nibble.config.release_feed, fetcher: method(:fetch))
        return [] if feed.blank?

        published(feed, fetcher).select { |release| Release.at_least?(release.version, current) && release.version != current }
      rescue StandardError => e
        Rails.logger.warn("release feed: #{e.message}")
        []
      end

      def published(feed, fetcher = method(:fetch))
        body = Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_FOR) { fetcher.call(feed) }
        Array(JSON.parse(body.to_s)).filter_map do |row|
          next unless Gem::Version.correct?(row["version"].to_s)

          Published.new(version: row["version"], url: row["url"], notes: row["notes"])
        end
      end

      # A plain GET of a published file: no headers, no query, nothing about this site leaves it.
      def fetch(feed)
        uri = URI.parse(feed)
        raise Error, "the release feed must be an https URL" unless uri.scheme == "https"

        Net::HTTP.get(uri)
      end
    end
  end
end
