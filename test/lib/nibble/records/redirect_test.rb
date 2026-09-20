require "test_helper"

class Nibble::Records::RedirectTest < ActiveSupport::TestCase
  Redirect = Nibble::Records::Redirect

  test "a redirect to an existing redirect's source goes straight to the final target" do
    Redirect.create!(from: "/b", to: "/c")
    assert_equal "/c", Redirect.create!(from: "/a", to: "/b").to
  end

  test "redirects pointing at a new redirect's source are re-pointed, so no chain is ever two hops" do
    first = Redirect.create!(from: "/a", to: "/b")
    Redirect.create!(from: "/b", to: "/c")
    assert_equal "/c", first.reload.to
  end

  test "loops are refused" do
    Redirect.create!(from: "/a", to: "/b")
    assert_not Redirect.new(from: "/b", to: "/a").valid?
  end

  test "a content move takes over a path that was a redirect source, since live content now lives there" do
    Redirect.create!(from: "/new", to: "/somewhere")
    Redirect.record_move("/old", "/new")

    assert_nil Redirect.find_by(from: "/new")
    assert_equal [ "/new", "auto", 301 ], Redirect.find_by!(from: "/old").then { |r| [ r.to, r.source, r.status ] }
  end

  test "moving back to an old URL replaces the reverse redirect instead of looping" do
    Redirect.record_move("/a", "/b")
    Redirect.record_move("/b", "/a")

    assert_nil Redirect.find_by(from: "/a")
    assert_equal "/a", Redirect.find_by!(from: "/b").to
  end
end
