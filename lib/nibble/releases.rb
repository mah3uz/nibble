require "net/http"

module Nibble
  module Releases
    mattr_accessor :fetcher

    CACHE_KEY = "nibble:releases".freeze
    SUMMARY_KEY = "nibble:releases:summary".freeze
    ASKED_KEY = "nibble:releases:asked".freeze
    KEEP_FOR = 7.days
    ASK_AGAIN_AFTER = 1.hour

    Published = Data.define(:version, :url, :body, :date, :security, :status)
    Summary = Data.define(:count, :security)

    CHECKING = "updates.checking".freeze

    # Ours, not a site's: nobody types in where their own CMS looks for updates. All a site decides is
    # whether to look at all, and it decides that in the control panel.
    def self.checking? = Records::Setting.read(CHECKING, true) != false

    def self.checking=(on)
      Records::Setting.write(CHECKING, on ? true : false)
      Rails.cache.delete(ASKED_KEY)
      on
    end

    def self.feed_url = checking? ? RELEASES_FEED : nil

    NOTHING = Summary.new(count: 0, security: false)

    class << self
      # Reads what the scheduled check last found. It never fetches: a slow feed must not hold up the
      # control panel, and a site that has just switched this on should not wait for the first request.
      def all(current: VERSION, feed: feed_url)
        return [] if feed.blank?

        body = Rails.cache.read(CACHE_KEY)
        return check_soon([]) if body.blank?

        parse(body).map { |release| release.with(status: status_of(release.version, current)) }
      rescue StandardError => e
        Rails.logger.warn("release feed: #{e.message}")
        []
      end

      def newer(current: VERSION, feed: feed_url) = all(current:, feed:).select { |release| release.status == "newer" }

      # What every control panel page reads: two numbers the daily check left behind, never the whole feed.
      def summary
        return NOTHING if feed_url.blank?

        cached = Rails.cache.read(SUMMARY_KEY)
        return check_soon(NOTHING) if cached.blank?

        Summary.new(count: cached["count"].to_i, security: cached["security"] == true)
      end

      def refresh
        refresh!
      rescue StandardError => e
        Rails.logger.warn("release feed: #{e.message}")
        false
      end

      def refresh!(feed: feed_url)
        return false if feed.blank?

        body = (fetcher || method(:fetch)).call(feed)
        waiting = parse(body).select { |release| status_of(release.version, VERSION) == "newer" }
        Rails.cache.write(CACHE_KEY, body, expires_in: KEEP_FOR)
        Rails.cache.write(SUMMARY_KEY, { "count" => waiting.size, "security" => waiting.any?(&:security) },
                          expires_in: KEEP_FOR)
        true
      end

      def parse(body)
        Array(JSON.parse(body.to_s)).filter_map do |row|
          next unless Gem::Version.correct?(row["version"].to_s)

          Published.new(version: row["version"], url: row["url"], date: row["date"], status: nil,
                        security: row["security"] == true, body: row["body"].to_s)
        end
      end

      # A plain GET of a published file: no headers, no query, nothing about this site leaves it. The
      # timeouts matter because the Updates screen fetches this while someone waits for the page.
      def fetch(feed)
        uri = URI.parse(feed)
        raise Error, "the release feed must be an https URL" unless uri.scheme == "https"

        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
          http.get(uri.request_uri).body
        end
      end

      private

      def status_of(version, current)
        case Gem::Version.new(version) <=> Gem::Version.new(current)
        when 1 then "newer"
        when 0 then "current"
        else "older"
        end
      end

      # Nothing has been fetched yet, so ask in the background and answer with what we have: nothing.
      def check_soon(answer)
        Jobs::CheckReleases.perform_later if Rails.cache.write(ASKED_KEY, true, expires_in: ASK_AGAIN_AFTER, unless_exist: true)
        answer
      end
    end
  end
end
