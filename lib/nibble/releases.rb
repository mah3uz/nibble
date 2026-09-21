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

    # Ours, not a site's: all a site chooses is whether to look.
    def self.checking? = Records::Setting.read(CHECKING, true) != false

    def self.checking=(on)
      Records::Setting.write(CHECKING, on ? true : false)
      Rails.cache.delete(ASKED_KEY)
      on
    end

    def self.feed_url = checking? ? RELEASES_FEED : nil

    # The feed is a projection of CHANGELOG.md, so the file a site reads cannot drift from the notes.
    KEEP_RELEASES = 25
    SECTION = /^## (\d+\.\d+\.\d+) — (\d{4}-\d{2}-\d{2})\n(.*?)(?=^## \d+\.\d+\.\d+ — |\z)/m

    def self.publish(changelog, to)
      url = REPOSITORY.delete_suffix(".git")
      releases = Pathname(changelog).read.scan(SECTION).first(KEEP_RELEASES).map do |version, date, body|
        { "version" => version, "date" => date, "url" => "#{url}/releases/tag/v#{version}",
          "security" => body.match?(/^##\s+Security\b/i), "body" => body.strip }
      end
      Pathname(to).write("#{JSON.pretty_generate(releases)}\n")
      releases
    end

    NOTHING = Summary.new(count: 0, security: false)

    class << self
      # Never fetches: a slow feed must not hold up a page.
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

      # What every page reads, so none of them parses the feed.
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

      # No headers, no query: nothing about this site leaves. Timeouts because a page waits on it.
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

      def check_soon(answer)
        Jobs::CheckReleases.perform_later if Rails.cache.write(ASKED_KEY, true, expires_in: ASK_AGAIN_AFTER, unless_exist: true)
        answer
      end
    end
  end
end
