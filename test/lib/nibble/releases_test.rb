require "test_helper"

class Nibble::ReleasesTest < ActiveSupport::TestCase
  setup { Rails.cache.clear }

  FEED = [ { "version" => "0.1.0" }, { "version" => "9.9.9", "url" => "https://example.com/9", "notes" => "big" } ].to_json

  test "no feed means no request, so an install that never opts in is never reached out on its behalf" do
    never = ->(_) { flunk "nothing may be fetched without a feed" }

    assert_empty Nibble::Releases.newer(feed: nil, fetcher: never)
    assert_empty Nibble::Releases.newer(feed: "", fetcher: never)
  end

  test "only releases newer than the one running are offered" do
    offered = Nibble::Releases.newer(current: "0.1.0", feed: "https://example.com/releases.json", fetcher: ->(_) { FEED })

    assert_equal [ "9.9.9" ], offered.map(&:version), "the release already installed is not news"
  end

  test "the feed must be https, so a release notice cannot be injected over plain http" do
    assert_raises(Nibble::Error) { Nibble::Releases.fetch("http://example.com/releases.json") }
  end

  test "an unreachable or malformed feed leaves the control panel alone" do
    feed = "https://example.com/releases.json"

    assert_empty Nibble::Releases.newer(current: "0.1.0", feed:, fetcher: ->(_) { raise SocketError, "no route" })
    Rails.cache.clear
    assert_empty Nibble::Releases.newer(current: "0.1.0", feed:, fetcher: ->(_) { "not json at all" })
  end

  test "a site has no feed until it sets one" do
    assert_nil Nibble.config.release_feed
  end

  test "the control panel wears a badge only once there is something to take" do
    utilities = ->(user) { Nibble::Cp::Navigation.for(user).flat_map { |section| section["items"] }.find { |item| item["title"] == "Utilities" } }

    assert_nil utilities.call(users(:admin))["badge"], "an install with no feed is never nagged"

    with_feed do
      updates = utilities.call(users(:admin))

      assert_equal 1, updates["badge"]
      assert_equal 1, updates["children"].find { |child| child["title"] == "Updates" }["badge"]
    end
  end

  private

  def with_feed(&)
    was = Nibble.config
    Nibble.config = Nibble::Config.new(Nibble.config_values.merge("release_feed" => "https://example.com/releases.json"))
    Nibble::Releases.fetcher = ->(_) { FEED }
    yield
  ensure
    Nibble.config = was
    Nibble::Releases.fetcher = nil
    Rails.cache.clear
  end
end
