require "test_helper"

class Admin::UpdatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    @was_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    releases = 25.times.map { |index| { "version" => "0.#{25 - index}.0", "body" => "Notes" } }
    @asked = []
    Nibble::Releases.fetcher = lambda do |url|
      number = url[/page=(\d+)/, 1].to_i
      @asked << number
      (releases.slice((number - 1) * 10, 10) || []).to_json
    end
  end

  teardown do
    Nibble::Releases.fetcher = nil
    Rails.cache = @was_cache
  end

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

  test "the page opens on the ten newest releases and says there are more" do
    get "/admin/updates"

    assert_equal 10, props["releases"].size
    assert_equal "0.25.0", props["releases"].first["version"]
    assert props["more"]
  end

  # Loading more adds to what is shown, so it answers with a merging prop and never re-reads the feed's first page.
  test "loading more brings the next ten to append, without reading the feed again from the top" do
    get "/admin/updates"
    @asked.clear
    version = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["version"]

    get "/admin/updates", params: { page: 3 }, headers: {
      "X-Inertia" => "true", "X-Inertia-Version" => version.to_s,
      "X-Inertia-Partial-Component" => "admin/Updates", "X-Inertia-Partial-Data" => "releases,page,more"
    }
    page = JSON.parse(response.body)

    assert_equal %w[0.5.0 0.1.0], page["props"]["releases"].values_at(0, -1).map { |release| release["version"] }
    assert_equal false, page["props"]["more"]
    assert_includes page["mergeProps"], "releases"
    assert_equal [ 3 ], @asked
  end
end
