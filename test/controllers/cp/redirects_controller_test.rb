require "test_helper"

class Nibble::Cp::RedirectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    Nibble::Records::Redirect.delete_all
  end

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def listing = page["props"]["listing"]
  def froms = listing["rows"].map { |row| row["from"] }

  def add(from, to: "/new", hits: 0, last_hit_at: nil, source: "manual")
    Nibble::Records::Redirect.create!(from:, to:, status: 301, source:, hits:, last_hit_at:)
  end

  test "a migrated site's hundreds of redirects arrive a page at a time, not all at once" do
    60.times { |index| add(format("/old-%03d", index)) }

    get "/cp/redirects"
    assert_equal 25, listing["rows"].size
    assert_equal 60, listing["pagination"]["total"]
    assert_equal 3, listing["pagination"]["pages"]

    get "/cp/redirects", params: { page: 3 }
    assert_equal [ "/old-050" ], froms.first(1)
    assert_equal 10, listing["rows"].size
  end

  test "search finds a redirect by either end, so a broken link can be traced from where it now points" do
    add("/blog/launch", to: "/news/launch")
    add("/about-us", to: "https://example.test/about")
    add("/sale-50-off", to: "/sale")
    add("/save-50%-today", to: "/sale")

    get "/cp/redirects", params: { q: "news" }
    assert_equal [ "/blog/launch" ], froms

    get "/cp/redirects", params: { q: "ABOUT" }
    assert_equal [ "/about-us" ], froms, "search ignores case"

    get "/cp/redirects", params: { q: "50%" }
    assert_equal [ "/save-50%-today" ], froms, "a % in the search is a character, not a wildcard"
  end

  test "sorting by hits or last hit surfaces the redirects that still matter" do
    add("/a", hits: 5, last_hit_at: 3.days.ago)
    add("/b", hits: 50, last_hit_at: 1.hour.ago)
    add("/c", hits: 0)

    get "/cp/redirects", params: { sort: "hits", dir: "desc" }
    assert_equal %w[/b /a /c], froms
    assert_equal({ "column" => "hits", "direction" => "desc", "disabled_reason" => nil }, listing["sort"])

    get "/cp/redirects", params: { sort: "last_hit_at", dir: "desc" }
    assert_equal %w[/b /a], froms.first(2)

    get "/cp/redirects", params: { sort: "status; DROP TABLE redirects" }
    assert_equal "from", listing["sort"]["column"], "only known columns are sortable"
  end

  test "rows say in words what each status does and how the redirect was added" do
    add("/moved", source: "auto")

    get "/cp/redirects"
    row = listing["rows"].sole
    assert_equal "Permanent (301)", row["status"]
    assert_equal 301, row["status_code"]
    assert_equal "auto", row["source"]
    assert_equal [ 301, 302, 307, 308 ], page["props"]["statuses"].map { |status| status["value"] }
    assert_equal "Temporary (302)", page["props"]["statuses"].second["label"]
  end

  test "bulk delete removes only the chosen redirects" do
    keep = add("/keep")
    gone = [ add("/gone-1"), add("/gone-2") ]

    post "/cp/actions", params: { resource: "redirects", handle: "delete", ids: gone.map(&:id) }, headers: { "Referer" => "http://www.example.com/cp/redirects?page=2" }

    assert_redirected_to "/cp/redirects?page=2"
    assert_equal "2 redirects deleted.", flash[:notice]
    assert_equal [ keep.id ], Nibble::Records::Redirect.pluck(:id)
  end

  test "bulk delete needs the same permission as the Redirects screen" do
    victim = add("/keep")
    sign_in_as users(:author)

    post "/cp/actions", params: { resource: "redirects", handle: "delete", ids: [ victim.id ] }

    assert_response :forbidden
    assert Nibble::Records::Redirect.exists?(victim.id)
  end

  test "a rejected redirect goes back to the same listing page with each error under its own field" do
    referer = "http://www.example.com/cp/redirects?page=2&q=old"

    post "/cp/redirects", params: { redirect: { from: "old-page", to: "javascript:alert(1)", status: 301 } }, headers: { "Referer" => referer }

    assert_redirected_to referer
    errors = session[:inertia_errors].with_indifferent_access
    assert_equal "From must be a path on this site, starting with /", errors[:from]
    assert_match "must be a path starting with /", errors[:to]
    assert_not Nibble::Records::Redirect.exists?(from: "old-page")
  end

  test "an edit that fails leaves the redirect as it was" do
    redirect = add("/old", to: "/new")

    patch "/cp/redirects/#{redirect.id}", params: { redirect: { from: "/old", to: "", status: 302 } }, headers: { "Referer" => "http://www.example.com/cp/redirects" }

    assert session[:inertia_errors].with_indifferent_access[:to].present?
    assert_equal [ "/new", 301 ], [ redirect.reload.to, redirect.status ]
  end
end
