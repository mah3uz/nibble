require "test_helper"

class NibbleSeoTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  setup { seed_starter_site }

  def head = Nokogiri::HTML(response.body).at_css("head")
  def json_ld = head.css('script[type="application/ld+json"]').map { |node| JSON.parse(node.text) }

  def with_indexing
    original = Nibble::Seo.method(:indexable?)
    Nibble::Seo.define_singleton_method(:indexable?) { true }
    yield
  ensure
    Nibble::Seo.define_singleton_method(:indexable?, original)
  end

  test "titles follow the SEO title template, and the canonical is absolute" do
    ok Nibble::Lifecycle.call(Nibble::Records::GlobalSet.new(handle: "seo", locale: "en"), :save, { "title_template" => "{title} | {site_name}" })

    get "/blog/grids"
    assert_equal "Grids | Starter", head.at_css("title").text
    assert_equal "https://example.test/blog/grids", head.at_css('link[rel="canonical"]')["href"]
    assert_equal "BlogPosting", json_ld.first["@type"]
  end

  test "an entry's SEO fields override its title and description, and noindex reaches robots" do
    grids = @posts[1]
    ok Nibble::Lifecycle.call(grids, :save, { "seo" => { "title" => "Grid systems explained", "description" => "Why grids work.", "noindex" => true } })
    ok Nibble::Lifecycle.call(grids.reload, :publish)

    with_indexing { get "/blog/grids" }
    assert_equal "Grid systems explained · Starter", head.at_css("title").text
    assert_equal "Why grids work.", head.at_css('meta[name="description"]')["content"]
    assert_equal "noindex, nofollow", head.at_css('meta[name="robots"]')["content"]
  end

  test "the favicon chosen in the site settings is the one browsers are pointed at" do
    get "/blog/grids"
    assert_nil head.at_css('link[rel="icon"]'), "no favicon set, no link to a missing file"

    icon = Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob: ActiveStorage::Blob.create_and_upload!(io: file_fixture("pixel.png").open, filename: "icon.png")), :create).record
    site = Nibble::Records::GlobalSet.find_by(handle: "site", locale: "en") || Nibble::Records::GlobalSet.new(handle: "site", locale: "en")
    ok Nibble::Lifecycle.call(site, :save, { "name" => "Starter", "favicon" => [ { "asset" => icon.id.to_s } ] })

    Nibble::Events.dispatch_pending
    get "/blog/grids"
    link = head.at_css('link[rel="icon"]')
    assert_equal [ icon.url, "image/png" ], [ link["href"], link["type"] ]
  end

  test "share images fall back from the page's featured image to the site default, as absolute og-sized URLs" do
    photo = Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob: ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "photo.jpg")), :create).record
    ok Nibble::Lifecycle.call(Nibble::Records::GlobalSet.new(handle: "seo", locale: "en"), :save, { "default_share_image" => { "asset" => photo.id.to_s } })

    get "/blog/grids"
    assert_equal "https://example.test#{photo.url('og')}", head.at_css('meta[property="og:image"]')["content"]
    assert_equal "summary_large_image", head.at_css('meta[name="twitter:card"]')["content"]
  end

  test "pages are indexable only where indexing is allowed, so staging never gets indexed" do
    get "/about"
    assert_equal "noindex, nofollow", head.at_css('meta[name="robots"]')["content"]

    Nibble::PageCache.store.clear
    with_indexing { get "/about" }
    assert_nil head.at_css('meta[name="robots"]')
  end

  test "the home page also describes the organization" do
    get "/"
    assert_equal [ "WebPage", "Organization" ], json_ld.map { |node| node["@type"] }
  end

  test "404 pages are never indexed" do
    with_indexing { get "/missing" }
    assert_equal "noindex, nofollow", head.at_css('meta[name="robots"]')["content"]
  end

  test "the sitemap index lists a sitemap per routed collection and taxonomy" do
    get "/sitemap.xml"
    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//loc").map(&:text)
    assert_equal %w[https://example.test/sitemap-pages.xml https://example.test/sitemap-posts.xml https://example.test/sitemap-taxonomy-topics.xml], locs
  end

  test "a collection sitemap lists live, indexable entries only" do
    ok Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts"), :create, { "title" => "Draft" })
    hidden = @posts[0]
    ok Nibble::Lifecycle.call(hidden, :save, { "seo" => { "noindex" => true } })
    ok Nibble::Lifecycle.call(hidden.reload, :publish)

    get "/sitemap-posts.xml"
    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//loc").map(&:text)
    assert_equal %w[grids remote-work type-scales].map { |slug| "https://example.test/blog/#{slug}" }, locs
    get "/sitemap-nope.xml"
    assert_response :not_found
  end

  test "a sitemap lists its addresses in order, whatever order the entries were created in" do
    %w[zebra-notes apple-notes].each do |slug|
      entry = Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts"), :create, { "title" => slug.titleize, "slug" => slug }).record
      ok Nibble::Lifecycle.call(entry, :publish, { "published_at" => 1.day.ago.utc.iso8601 })
    end

    get "/sitemap-posts.xml"

    locs = Nokogiri::XML(response.body).remove_namespaces!.xpath("//loc").map(&:text)
    assert_equal locs.sort, locs
    assert_includes locs, "https://example.test/blog/apple-notes"
  end

  test "robots.txt allows crawling and points at the sitemap only where indexing is allowed" do
    get "/robots.txt"
    assert_equal "User-agent: *\nDisallow: /\n", response.body

    with_indexing { get "/robots.txt" }
    assert_includes response.body, "Sitemap: https://example.test/sitemap.xml"
  end
end
