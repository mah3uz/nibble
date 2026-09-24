require "net/http"

module Nibble
  module Releases
    mattr_accessor :fetcher

    CACHE_KEY = "nibble:releases".freeze
    SUMMARY_KEY = "nibble:releases:summary".freeze
    ASKED_KEY = "nibble:releases:asked".freeze
    KEEP_FOR = 7.days
    PER_PAGE = 10
    MAX_PAGES = 20
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

    def self.feed_url = checking? ? CHANGELOGS_FEED : nil

    # The feed is a projection of CHANGELOG.md, every release of it, so the file a site reads cannot drift from the notes.
    SECTION = /^## (\d+\.\d+\.\d+) — (\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2} [-+]\d{4})?)\n(.*?)(?=^## \d+\.\d+\.\d+ — |\z)/m

    def self.publish(changelog, to)
      url = REPOSITORY.delete_suffix(".git")
      releases = Pathname(changelog).read.scan(SECTION).map do |version, released_at, body|
        { "version" => version, "date" => released_at[0, 10], "released_at" => released_at,
          "url" => "#{url}/releases/tag/v#{version}", **lead(body),
          "security" => body.match?(/^\#+\s+Security\b/i), "body" => body.strip }
      end
      Pathname(to).write("#{JSON.pretty_generate(releases)}\n")
      releases
    end

    # A quote opening a release's notes says what it was for: the bold words are its headline, the rest its summary.
    def self.lead(body)
      quote = body.lstrip[/\A(?:>.*(?:\n|\z))+/].to_s.gsub(/^>[ \t]?/, "").squish
      match = quote.match(/\A\*\*(.+?)\*\*\s*(.*)\z/) or return {}
      { "headline" => match[1].strip.delete_suffix("."), "summary" => match[2].presence }.compact
    end

    NOTHING = Summary.new(count: 0, security: false)

    class << self
      # Never fetches: a slow feed must not hold up a page.
      def all(current: VERSION, feed: feed_url)
        return [] if feed.blank?

        cached = Rails.cache.read(CACHE_KEY)
        return check_soon([]) if cached.blank?

        with_status(parse(cached["releases"]), current)
      rescue StandardError => e
        Rails.logger.warn("release feed: #{e.message}")
        []
      end

      # Someone asking for older releases is waiting on the answer, so a page beyond what refresh kept is fetched.
      def page(number, current: VERSION, feed: feed_url)
        return [] if feed.blank?

        cached = Rails.cache.read(CACHE_KEY) || { "releases" => [], "complete" => false }
        rows = cached["releases"].slice((number - 1) * PER_PAGE, PER_PAGE) || []
        rows = page_rows(feed, number) if rows.size < PER_PAGE && !cached["complete"]
        with_status(parse(rows), current)
      rescue StandardError => e
        Rails.logger.warn("release feed: #{e.message}")
        []
      end

      def last_page?(number)
        cached = Rails.cache.read(CACHE_KEY)
        cached.present? && cached["complete"] && cached["releases"].size <= number * PER_PAGE
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

      # Pages are read until one reaches the running release, so a site far behind still counts every release it lacks.
      def refresh!(feed: feed_url, current: VERSION)
        return false if feed.blank?

        rows = []
        complete = false
        (1..MAX_PAGES).each do |number|
          fetched = Array(JSON.parse(fetch_page(feed, number).to_s))
          # A feed that doesn't know pages sends everything, whatever was asked.
          if fetched.size > PER_PAGE
            rows = fetched
            complete = true
            break
          end
          rows.concat(fetched)
          complete = fetched.size < PER_PAGE
          break if complete || parse(fetched).any? { |release| status_of(release.version, current) != "newer" }
        end
        waiting = parse(rows).select { |release| status_of(release.version, current) == "newer" }
        Rails.cache.write(CACHE_KEY, { "releases" => rows, "complete" => complete }, expires_in: KEEP_FOR)
        Rails.cache.write(SUMMARY_KEY, { "count" => waiting.size, "security" => waiting.any?(&:security) },
                          expires_in: KEEP_FOR)
        true
      end

      def parse(rows)
        rows = JSON.parse(rows.to_s) if rows.is_a?(String)
        Array(rows).filter_map do |row|
          next unless Gem::Version.correct?(row["version"].to_s)

          Published.new(version: row["version"], url: row["url"], date: row["date"], status: nil,
                        security: row["security"] == true, body: row["body"].to_s)
        end
      end

      # No headers, and a query naming only a page: nothing about this site leaves. Timeouts because a page waits on it.
      def fetch(feed)
        uri = URI.parse(feed)
        raise Error, "the release feed must be an https URL" unless uri.scheme == "https"

        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
          http.get(uri.request_uri).body
        end
      end

      private

      def fetch_page(feed, number) = (fetcher || method(:fetch)).call("#{feed}?page=#{number}&per_page=#{PER_PAGE}")

      def page_rows(feed, number)
        fetched = Array(JSON.parse(fetch_page(feed, number).to_s))
        fetched.size > PER_PAGE ? fetched.slice((number - 1) * PER_PAGE, PER_PAGE) || [] : fetched
      end

      def with_status(releases, current) = releases.map { |release| release.with(status: status_of(release.version, current)) }

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
