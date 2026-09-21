require "test_helper"

class Nibble::FeedsTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  setup { seed_starter_site }

  def feed(path)
    get path
    assert_response :success
    Nokogiri::XML(response.body).remove_namespaces!
  end

  test "a collection that asks for a feed gets one, newest first" do
    doc = feed("/feed-posts.xml")

    assert_equal [ "Type scales", "Remote work", "Grids", "Colour theory" ], doc.css("entry > title").map(&:text),
      "a reader subscribes to see what is new, so the newest post has to come first"
    assert_equal "https://example.test/blog/type-scales", doc.css("entry > link").first["href"]
  end

  test "the feed is only the live pages, because that is what a subscriber can open" do
    ok Nibble::Lifecycle.call(@posts.last, :unpublish)

    refute_includes feed("/feed-posts.xml").css("entry > title").map(&:text), "Type scales"
  end

  test "a collection that never asked for a feed has none" do
    get "/feed-pages.xml"

    assert_response :not_found, "a feed is opt-in; every collection having one would publish pages nobody meant to syndicate"
  end

  test "the site feed carries everything that publishes one" do
    assert_equal 4, feed("/feed.xml").css("entry").size
  end

  test "a page announces the feed, which is how a reader finds it without being told" do
    get "/blog"

    link = Nokogiri::HTML(response.body).at_css('link[rel="alternate"][type="application/atom+xml"]')
    assert_equal "https://example.test/feed.xml", link&.[]("href")
  end

  test "the feed is well-formed Atom, so a reader can actually parse it" do
    doc = Nokogiri::XML(feed("/feed-posts.xml").to_xml)

    assert_empty doc.errors
    assert_equal "https://example.test/feed-posts.xml", doc.css("feed > link[rel='self']").first["href"]
    assert doc.css("feed > updated").first.text.present?, "a reader polls on updated, so it has to be there"
  end
end
