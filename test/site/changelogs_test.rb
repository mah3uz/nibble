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

  # A Control Plane decides whether to offer an upgrade from this response, so it has to be the feed itself and
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

  test "no feed answers not found, rather than an empty list a Control Plane would take as no releases" do
    @content.join("changelogs/releases.json").delete
    get "/api/v1/changelogs"

    assert_response :not_found
  end

  def write_releases(count)
    releases = count.times.map { |index| { "version" => "0.#{count - index}.0", "date" => "2026-01-01", "security" => false } }
    @content.join("changelogs/releases.json").write(JSON.generate(releases))
  end

  # A Control Plane shows ten at a time, so it asks for a page rather than every release it would never scroll to.
  test "a page of the feed is that slice, newest first, with how many there are in all" do
    write_releases(23)
    get "/api/v1/releases", params: { page: 3, per_page: 10 }

    assert_equal %w[0.3.0 0.2.0 0.1.0], JSON.parse(response.body).map { |release| release["version"] }
    assert_equal "23", response.headers["x-total-count"]
    assert_equal "3", response.headers["x-last-page"]
  end

  test "a page past the end is empty, and a page asked for without a size is ten" do
    write_releases(12)

    get "/api/v1/releases", params: { page: 9 }
    assert_equal [], JSON.parse(response.body)

    get "/api/v1/releases", params: { page: 1 }
    assert_equal 10, JSON.parse(response.body).size
  end
end
