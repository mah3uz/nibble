require "test_helper"

class NibbleCrumbsTest < ActionDispatch::IntegrationTest
  QUERY_BUDGET = 15

  setup do
    # Crumbs' demo content is imported against crumbs' own blueprints, so the site's schema stays out of it.
    Nibble.config = Nibble::Config.new(Nibble.config_values.merge("theme" => "crumbs"),
      site_schema_path: Rails.root.join("test/nibble_themes/no_site_schema"))
    Nibble.reset_schema!
    Nibble.boot!
    Nibble::PageCache.store = ActiveSupport::Cache::MemoryStore.new
    [ Nibble::Records::Entry, Nibble::Records::Term, Nibble::Records::GlobalSet, Nibble::Records::NavigationTree ].each(&:delete_all)
    report = Nibble::Packages::Importer.new(Rails.root.join("themes/crumbs/content")).call
    assert report.ok?, report.errors.join("\n")
    Nibble::Events.dispatch_pending
    Nibble::PageCache.store.clear
  end

  teardown do
    Nibble::PageCache.store = nil
    Nibble.config = nil
    Nibble.reset_schema!
    Nibble::Search.rebuild
  end

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def text = Nokogiri::HTML(response.body).text

  test "the demo package is a complete site: every page type renders inside the query budget" do
    {
      "/" => "theme/home", "/blog" => "theme/posts/index", "/blog/the-first-crumb" => "theme/posts/show",
      "/about" => "theme/about", "/search" => "theme/search", "/topics" => "theme/topics/index",
      "/topics/slow-work" => "theme/topics/show", "/authors/mo-ferris" => "theme/authors/show"
    }.each do |path, component|
      get path
      assert_response :success, path
      assert_equal component, props["component"], path
      assert_operator response.headers["X-Nibble-Queries"].to_i, :<=, QUERY_BUDGET, "#{path} ran #{response.headers['X-Nibble-Queries']} queries"
    end
  end

  test "the home page shows the newest article, more articles and every topic" do
    get "/"
    page = props["props"]

    assert_equal "Crumbs left by people who make things", page["page"]["title"]
    assert_equal [ "The week I renamed one thing" ], page["featured"].map { |post| post["title"] }
    assert_equal 5, page["recent"].size
    assert_equal [ "Reading", "Slow work", "Tools" ], page["topics"].map { |topic| topic["title"] }
    assert_equal [ "Archive", "Topics", "About" ], page["site"]["navigation"]["main"].map { |link| link["title"] }
  end

  test "an article renders its body, byline, topics and related articles" do
    get "/blog/the-week-i-renamed-one-thing"
    page = props["props"]["page"]

    assert_includes page["body"], "<h2>Why bother</h2>"
    assert_equal "Mo Ferris", page["authors"]["title"]
    assert_equal [ "Slow work" ], page["topics"].map { |topic| topic["title"] }
    assert_equal [ "Tools that earned their keep", "Throwing away a feature nobody asked for", "The first crumb" ], props["props"]["related"].map { |post| post["title"] }
  end

  test "page blocks render through their set views" do
    get "/about"
    blocks = props["props"]["page"]["blocks"]

    assert_equal %w[rich_text quote], blocks.map { |block| block["type"] }
    assert_includes blocks.first["text"], "<p>We started Crumbs"
    assert_equal "The house rules", blocks.last["attribution"]
  end

  test "search finds articles by word, with the term highlighted" do
    Nibble::Search.rebuild

    get "/search", params: { q: "changelog" }
    results = props["props"]["results"]["data"]
    assert_equal [ "What a good changelog sounds like" ], results.map { |result| result["title"] }
    assert_includes results.first["search_snippet"], "<mark>"
  end

  test "the archive paginates, and a topic page lists only its own articles" do
    get "/blog"
    assert_equal 6, props["props"]["posts"]["data"].size

    get "/topics/tools"
    assert_equal [ "Tools that earned their keep", "Throwing away a feature nobody asked for", "What a good changelog sounds like" ].sort,
      props["props"]["posts"]["data"].map { |post| post["title"] }.sort
  end

  test "SEO and the sitemap describe the imported site" do
    get "/blog/the-first-crumb"
    head = Nokogiri::HTML(response.body).at_css("head")
    assert_equal "The first crumb · Crumbs", head.at_css("title").text
    assert_equal "#{Nibble.config.url}/blog/the-first-crumb", head.at_css('link[rel="canonical"]')["href"]

    get "/sitemap-posts.xml"
    assert_equal 6, Nokogiri::XML(response.body).remove_namespaces!.xpath("//url").size
  end

  test "an unknown path renders the theme's own 404" do
    get "/no-such-crumb"
    assert_response :not_found
    assert_equal "theme/errors/404", props["component"]
  end
end
