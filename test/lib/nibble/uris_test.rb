require "test_helper"

class Nibble::UrisTest < ActiveSupport::TestCase
  Record = Struct.new(:route, :slug, :published_at, :parent, :locale, :uri, keyword_init: true)

  test "tokens fill from the record and the result is a normalized path" do
    record = Record.new(route: "/blog/{year}/{month}/{slug}/", slug: "hello", published_at: Time.utc(2026, 3, 9), locale: "en")
    assert_equal "/blog/2026/03/hello", Nibble::Uris.for(record)
  end

  test "a root entry of a tree route has no leading parent segment" do
    parent = Record.new(uri: "/guides")
    assert_equal "/setup", Nibble::Uris.for(Record.new(route: "{parent_uri}/{slug}", slug: "setup", locale: "en"))
    assert_equal "/guides/setup", Nibble::Uris.for(Record.new(route: "{parent_uri}/{slug}", slug: "setup", parent:, locale: "en"))
  end

  test "a structure nests under a prefix of its own without the parent's URI doubling it" do
    guides = Record.new(uri: "/docs/guides", slug: "guides", locale: "en")
    nested = Record.new(uri: "/docs/guides/linux", slug: "linux", parent: guides, locale: "en")

    assert_equal "/docs/setup", Nibble::Uris.for(Record.new(route: "/docs{parent_slugs}/{slug}", slug: "setup", locale: "en"))
    assert_equal "/docs/guides/setup",
      Nibble::Uris.for(Record.new(route: "/docs{parent_slugs}/{slug}", slug: "setup", parent: guides, locale: "en"))
    assert_equal "/docs/guides/linux/setup",
      Nibble::Uris.for(Record.new(route: "/docs{parent_slugs}/{slug}", slug: "setup", parent: nested, locale: "en")),
      "{parent_uri} would give /docs/docs/guides/linux/setup, because the parent's URI already carries the prefix"
  end

  test "no URI until every token has a value, so an undated post doesn't get a broken URL" do
    assert_nil Nibble::Uris.for(Record.new(route: "/blog/{year}/{slug}", slug: "x", locale: "en"))
    assert_nil Nibble::Uris.for(Record.new(route: "/blog/{slug}", slug: nil, locale: "en"))
    assert_nil Nibble::Uris.for(Record.new(route: "/blog/{unknown}", slug: "x", locale: "en"))
  end
end
