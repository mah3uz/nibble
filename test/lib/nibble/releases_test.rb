require "test_helper"

class Nibble::ReleasesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  FEED = [
    { "version" => "0.1.0" },
    { "version" => "9.9.9", "url" => "https://example.com/9", "date" => "2026-09-21", "security" => true,
      "body" => "## What's new\n\n- A thing\n\n## What's fixed\n" }
  ].to_json

  test "a site that switches checking off is never reached out on its behalf" do
    Nibble::Releases.fetcher = ->(_) { flunk "nothing may be fetched once a site has said not to" }

    with_feed(checking: false) do
      assert_nil Nibble::Releases.feed_url
      assert_empty Nibble::Releases.newer
      assert_not Nibble::Releases.refresh!
    end
  ensure
    Nibble::Releases.fetcher = nil
  end

  test "checking is a switch in the control panel, not a line in a file, and it is on to begin with" do
    assert Nibble::Releases.checking?, "a site that has never touched it still hears about releases"

    Nibble::Releases.checking = false

    assert_not Nibble::Releases.checking?
    assert_nil Nibble::Releases.feed_url, "switched off means nothing is fetched, not merely hidden"
    assert_equal false, Nibble::Records::Setting.read(Nibble::Releases::CHECKING), "it has to outlive the request"
  ensure
    Nibble::Releases.checking = true
  end

  test "where to look is ours, so an install checks without being told where" do
    assert_equal Nibble::CHANGELOGS_FEED, Nibble::Releases.feed_url
    assert Nibble::Releases.checking?, "a site that says nothing still gets told a release exists"
  end

  test "only releases newer than the one running are offered" do
    with_feed do
      offered = Nibble::Releases.newer(current: "0.1.0")

      assert_equal [ "9.9.9" ], offered.map(&:version), "the release already installed is not news"
    end
  end

  test "the feed must be https, so a release notice cannot be injected over plain http" do
    assert_raises(Nibble::Error) { Nibble::Releases.fetch("http://example.com/releases.json") }
  end

  test "an unreachable feed leaves the control panel alone" do
    with_feed(prime: false) do
      Nibble::Releases.fetcher = ->(_) { raise SocketError, "no route" }

      assert_raises(SocketError) { Nibble::Releases.refresh! }
      assert_empty Nibble::Releases.newer(current: "0.1.0")
    end
  end


  test "a release carries its changelog as the Markdown it was written in" do
    with_feed do
      release = Nibble::Releases.newer(current: "0.1.0").sole

      assert_equal "## What's new\n\n- A thing\n\n## What's fixed\n", release.body,
                   "it is passed through untouched, so rendering it is a decision the control panel makes later"
      assert_equal "2026-09-21", release.date
    end
  end

  test "every release is listed, with the one this site runs marked among them" do
    with_feed do
      listed = Nibble::Releases.all(current: "0.1.0").to_h { |release| [ release.version, release.status ] }

      assert_equal({ "0.1.0" => "current", "9.9.9" => "newer" }, listed,
                   "the page is a changelog, so what came before has to be readable too")
    end
  end

  test "a release that fixes a security hole says so, because waiting on that one is a decision" do
    with_feed do
      assert Nibble::Releases.newer(current: "0.1.0").any?(&:security)
      assert_empty Nibble::Releases.newer(current: "9.9.9"), "a fix already installed is not a warning"
    end
  end

  test "a page render costs two cached numbers, not the whole feed" do
    with_feed do
      Nibble::Releases.fetcher = ->(_) { flunk "the sidebar must never fetch, on any page" }
      waiting = Nibble::Releases.summary

      assert_equal 1, waiting.count
      assert waiting.security, "how urgent it is has to survive into the cheap answer, or the badge cannot show it"
    end
  end

  test "the sidebar wears a badge only once there is something to take" do
    updates = ->(user) { Nibble::Cp::Navigation.for(user).flat_map { |section| section["items"] }.find { |item| item["title"] == "Updates" } }

    assert_nil updates.call(users(:admin))["badge"], "an install with no feed is never nagged"

    with_feed do
      assert_equal 1, updates.call(users(:admin))["badge"], "the count has to be visible without opening anything"
    end
  end

  test "the control panel never waits on the feed: it reads what the scheduled check left" do
    with_feed(prime: false) do
      Nibble::Releases.fetcher = ->(_) { flunk "a slow feed must not hold up a control panel page" }

      assert_empty Nibble::Releases.newer(current: "0.1.0")
      assert_enqueued_with job: Nibble::Jobs::CheckReleases
    end
  end

  test "the scheduled check is what fills it, and a bad feed leaves the last good answer alone" do
    with_feed(prime: false) do
      Nibble::Releases.fetcher = ->(_) { FEED }

      assert Nibble::Releases.refresh!
      assert_equal [ "9.9.9" ], Nibble::Releases.newer(current: "0.1.0").map(&:version)

      Nibble::Releases.fetcher = ->(_) { "not json at all" }
      assert_raises(JSON::ParserError) { Nibble::Releases.refresh! }
      assert_equal [ "9.9.9" ], Nibble::Releases.newer(current: "0.1.0").map(&:version)
    end
  end

  private

  # The test environment caches nothing, and what the scheduled check leaves behind is the whole point here.
  def with_feed(prime: true, checking: true)
    was_config = Nibble.config
    was_cache = Rails.cache
    Nibble::Releases.checking = checking
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    if prime
      Nibble::Releases.fetcher = ->(_) { FEED }
      Nibble::Releases.refresh!
      Nibble::Releases.fetcher = nil
    end
    yield
  ensure
    Nibble.config = was_config
    Rails.cache = was_cache
    Nibble::Releases.checking = true
    Nibble::Releases.fetcher = nil
  end

  test "a release records when it was cut, so a feed read from another zone lands on the same day" do
    changelog = Pathname(Dir.mktmpdir).join("CHANGELOG.md")
    changelog.write(<<~MD)
      # Changelog

      ## Unreleased

      ## 0.2.0 — 2026-02-01 04:56 +1000

      ### What's new

      - Cut in the morning east of UTC, where UTC is still on the day before.

      ## 0.1.0 — 2026-01-01

      ### What's new

      - From before a release carried a time.
    MD

    releases = Nibble::Releases.publish(changelog, changelog.dirname.join("releases.json"))

    assert_equal "2026-02-01 04:56 +1000", releases.first["released_at"], "the instant, offset and all, is what a page can be dated by"
    assert_equal "2026-02-01", releases.first["date"], "the day a site shows is the day it was cut, not the day UTC was on"
    assert_equal "2026-01-01", releases.last["released_at"], "an entry written before this still reads, as the day itself"
    assert_equal "2026-01-01", releases.last["date"]
  end

  test "the feed is a projection of the changelog, so what a site reads cannot drift from the notes" do
    changelog = Pathname(Dir.mktmpdir).join("CHANGELOG.md")
    changelog.write(<<~MD)
      # Changelog

      ## Unreleased

      ## 0.2.0 — 2026-02-01

      ### Security

      - A fix that matters.

      ### What's new

      - Something else.

      ## 0.1.0 — 2026-01-01

      ### What's new

      - The first one.
    MD
    feed = changelog.dirname.join("releases.json")

    releases = Nibble::Releases.publish(changelog, feed)

    assert_equal %w[0.2.0 0.1.0], releases.map { |release| release["version"] }, "newest first, and Unreleased is not one"
    assert releases.first["security"], "a Security section is what tells a site to upgrade now"
    assert_not releases.last["security"]
    assert_includes releases.first["body"], "- Something else.", "the whole entry travels, not the first section"
    assert_equal releases, JSON.parse(feed.read)
  end

  test "every release is published, so the oldest keep their notes and their pages on the documentation site" do
    changelog = Pathname(Dir.mktmpdir("nibble-feed")).join("CHANGELOG.md")
    changelog.write((1..40).reverse_each.map { |minor| "## 0.#{minor}.0 — 2026-01-01\n\n- Release #{minor}.\n" }.join("\n"))

    releases = Nibble::Releases.publish(changelog, changelog.dirname.join("releases.json"))

    assert_equal 40, releases.size
    assert_equal "0.1.0", releases.last["version"]
  ensure
    FileUtils.rm_rf(changelog.dirname) if changelog
  end
end
