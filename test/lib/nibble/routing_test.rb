require "test_helper"

class Nibble::RoutingTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  setup { seed_starter_site }

  test "the root-level page slugged home is the site root" do
    match = Nibble::Routing.resolve("/")
    assert_equal [ :entry, @home, "home" ], [ match.kind, match.record, match.template ]
  end

  test "entries, terms and taxonomy index routes resolve with their templates" do
    assert_equal "posts/show", Nibble::Routing.resolve("/blog/grids").template
    assert_equal "pages/show", Nibble::Routing.resolve("/about/team").template
    assert_equal [ :term, "taxonomies/show" ], Nibble::Routing.resolve("/topics/design").then { |m| [ m.kind, m.template ] }
    assert_equal [ :taxonomy, "taxonomies/index" ], Nibble::Routing.resolve("/topics").then { |m| [ m.kind, m.template ] }
  end

  test "only live entries resolve, and non-canonical spellings redirect" do
    ok Nibble::Lifecycle.call(@about, :unpublish)
    assert_nil Nibble::Routing.resolve("/about")
    assert_equal "/blog/grids", Nibble::Routing.resolve("/BLOG/grids/").redirect
    assert_nil Nibble::Routing.resolve("/nowhere/")
  end
end
