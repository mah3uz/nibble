require "test_helper"

class SiteChangelogsTest < ActionDispatch::IntegrationTest
  FEED = %([{"version":"9.9.9","date":"2026-01-01","security":false}]\n).freeze

  setup do
    @content = Pathname(Dir.mktmpdir("nibble-feed"))
    @content.join("changelogs").mkpath
    @content.join("changelogs/releases.json").write(FEED)
    Nibble.config = Nibble::Config.new(Nibble.config_values, content_path: @content)
  end

  teardown do
    Nibble.config = nil
    FileUtils.rm_rf(@content)
  end

  # A control panel decides whether to offer an upgrade from this response, so it has to be the feed itself and
  # not a re-rendering of it: a difference here is a difference between what two installations are told.
  test "the release feed is served exactly as it is written" do
    get "/api/v1/changelogs"

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal FEED, response.body
  end

  # An installation has its feed address compiled in, so both must answer identically: otherwise whether a site
  # is offered an upgrade would depend on which address it happens to hold.
  test "both feed addresses serve the same bytes" do
    get "/api/v1/releases"

    assert_equal FEED, response.body
  end

  test "no feed answers not found, rather than an empty list a control panel would take as no releases" do
    @content.join("changelogs/releases.json").delete
    get "/api/v1/changelogs"

    assert_response :not_found
  end

  # Two letters is the point at which a result is worth reading; below it the index matches almost everything,
  # which reads as noise and costs a query per keystroke.
  test "search says nothing until the query is worth running" do
    get "/api/v1/search", params: { q: "a" }

    assert_response :success
    assert_empty JSON.parse(response.body)["results"]
  end
end
