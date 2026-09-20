require "test_helper"

# Every page type of a starter-shaped site renders from queries, within the query budget, and is served from the
# page cache until content it depends on changes.
class NibbleSiteTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  QUERY_BUDGET = 15

  setup { seed_starter_site }

  test "every page type renders from its queries within the query budget" do
    pages = {
      "/" => "theme/home", "/blog" => "theme/posts/index", "/blog/grids" => "theme/posts/show", "/about/team" => "theme/pages/show",
      "/topics/design" => "theme/taxonomies/show", "/topics" => "theme/taxonomies/index"
    }
    pages.each do |path, component|
      get path
      assert_response :success, path
      assert_equal component, page_props["component"], path
      assert_operator query_count, :<=, QUERY_BUDGET, "#{path} ran #{query_count} queries"
    end
  end

  test "the blog index paginates live posts with their topics, newest first" do
    get "/blog", params: { page: 2, utm_source: "newsletter" }
    props = page_props["props"]

    assert_equal [ "Grids", "Colour theory" ], props["posts"]["data"].map { |post| post["title"] }
    assert_equal({ "current_page" => 2, "per_page" => 2, "total" => 4, "last_page" => 2 }, props["posts"]["meta"])
    assert_equal [ "Design" ], props["posts"]["data"].first["topics"].map { |topic| topic["title"] }
    assert_equal({ "page" => "2" }, props["site"]["params"], "only declared params reach the view and the cache key")
  end

  test "a post shows related posts through its topics, never itself, plus site globals and navigation" do
    get "/blog/type-scales"
    props = page_props["props"]

    assert_equal "Type scales", props["page"]["title"]
    assert_equal "https://example.test/blog/type-scales", props["page"]["url"]
    assert_equal [ "Remote work", "Grids", "Colour theory" ], props["more"].map { |post| post["title"] }
    assert_equal "Starter", props["site"]["globals"]["site"]["name"]
    assert_equal [ "Blog", "About" ], props["site"]["navigation"]["main"].map { |link| link["title"] }
    assert_equal "/about/team", props["site"]["navigation"]["main"].last["children"].first["url"]
  end

  test "drafts and trashed entries are never public" do
    draft = ok(Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts"), :create, { "title" => "Secret", "topics" => [ @design.id.to_s ] }))

    get draft.uri
    assert_response :not_found
    get "/topics/design"
    assert_not_includes page_props["props"]["posts"]["data"].map { |post| post["title"] }, "Secret"
  end

  test "a second request is served from the page cache with its dependency tags" do
    get "/blog"
    assert_nil response.headers["X-Nibble-Cache"]
    tags = response.headers["Surrogate-Key"].split

    get "/blog"
    assert_equal "hit", response.headers["X-Nibble-Cache"]
    assert_includes tags, "collection:posts"
    assert_includes tags, "entry:#{@blog.id}"
    assert_includes tags, "term:#{@design.id}"
  end

  test "publishing purges exactly the pages that depend on the change" do
    %w[/blog?page=2 /topics/culture /about/team].each { |path| get path }

    grids = @posts[1]
    ok Nibble::Lifecycle.call(grids, :save, { "title" => "Grids, revisited" })
    ok Nibble::Lifecycle.call(grids.reload, :publish)
    Nibble::Events.dispatch_pending

    get "/blog?page=2"
    assert_nil response.headers["X-Nibble-Cache"], "the blog lists posts, so it must re-render"
    assert_includes page_props["props"]["posts"]["data"].map { |post| post["title"] }, "Grids, revisited"
    get "/topics/culture"
    assert_nil response.headers["X-Nibble-Cache"], "queries over posts are tagged with the collection"
    get "/about/team"
    assert_equal "hit", response.headers["X-Nibble-Cache"], "an unrelated page stays cached"
  end

  test "saving a draft of a live post leaves every cached page alone" do
    get "/blog"
    ok Nibble::Lifecycle.call(@posts.first, :save, { "title" => "Not yet" })
    Nibble::Events.dispatch_pending

    get "/blog"
    assert_equal "hit", response.headers["X-Nibble-Cache"]
  end

  test "signed-in visitors always get a fresh render" do
    sign_in_as users(:editor)
    get "/blog"
    get "/blog"
    assert_nil response.headers["X-Nibble-Cache"]
  end

  test "case and trailing-slash variants 301 to the canonical URI, keeping the query" do
    get "/Blog/Grids/?ref=x"
    assert_redirected_to "/blog/grids?ref=x"
    assert_response :moved_permanently
  end

  test "an unknown path renders the theme's 404 and is logged for redirect suggestions" do
    2.times { get "/no-such-page", headers: { "HTTP_REFERER" => "https://elsewhere.test/" } }

    assert_response :not_found
    assert_equal "theme/errors/404", page_props["component"]
    log = Nibble::Records::NotFound.find_by!(path: "/no-such-page")
    assert_equal [ 2, "https://elsewhere.test/" ], [ log.hits, log.referrer ]
  end

  test "a render failure falls back to the theme's 500 page and is never cached" do
    Nibble::Presenter.define_singleton_method(:new) { |**| raise "view query exploded" }
    begin
      get "/blog"
    ensure
      Nibble::Presenter.singleton_class.remove_method(:new)
    end
    assert_response :internal_server_error
    assert_equal "theme/errors/500", page_props["component"]

    get "/blog"
    assert_response :success
    assert_nil response.headers["X-Nibble-Cache"]
  end

  test "redirect rules run before routing: exact, wildcard, query kept, hits counted" do
    exact = Nibble::Records::Redirect.create!(from: "/old-blog", to: "/blog")
    Nibble::Records::Redirect.create!(from: "/archive/*", to: "/blog/*", status: 308)

    get "/old-blog?page=2"
    assert_redirected_to "/blog?page=2"
    get "/archive/grids"
    assert_response 308
    assert_equal "/blog/grids", response.location
    assert_equal 1, exact.reload.hits
  end

  test "each set instance gets its own sidecar results, and the view gets its collection layout" do
    about = Nibble::Records::Entry.find(@about.id)
    ok Nibble::Lifecycle.call(about, :save, { "blocks" => [ { "type" => "quote", "quote" => "Less, but better." } ] })
    ok Nibble::Lifecycle.call(about.reload, :publish)

    get "/about"
    props = page_props["props"]
    assert_equal "default", props["layout"]
    block = props["page"]["blocks"].first
    assert_equal "Less, but better.", block["quote"]
    assert_equal [ "Type scales" ], block["queries"]["latest"].map { |post| post["title"] }
  end
end
