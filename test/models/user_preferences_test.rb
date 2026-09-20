require "test_helper"

class UserPreferencesTest < ActiveSupport::TestCase
  test "unknown keys are rejected, not silently ignored" do
    user = users(:editor)
    assert_raises(UserPreferences::InvalidValue) { UserPreferences.set!(user, "nonsense", "x") }
    assert_equal({}, user.reload.preferences, "a typo can't silently create a dead preference")
  end

  test "a value of the wrong type is rejected" do
    user = users(:editor)
    assert_raises(UserPreferences::InvalidValue) { UserPreferences.set!(user, "theme", "purple") }
    assert_raises(UserPreferences::InvalidValue) { UserPreferences.set!(user, "sidebar_collapsed", "yes") }
  end

  test "setting a nested key leaves its siblings alone" do
    user = users(:editor)
    UserPreferences.set!(user, "assets.view", "table")
    UserPreferences.set!(user, "theme", "dark")

    assert_equal "table", UserPreferences.get(user, "assets.view")
    assert_equal "dark", UserPreferences.get(user, "theme")
  end

  test "setting a value to nil resets it to the default instead of storing nil" do
    user = users(:editor)
    UserPreferences.set!(user, "theme", "dark")
    UserPreferences.set!(user, "theme", nil)

    assert_equal "system", UserPreferences.get(user, "theme")
    assert_not user.reload.preferences.key?("theme"), "a reset key shouldn't linger as a stored nil"
  end

  test "a listing preset list is validated by shape, not stored one row per handle" do
    user = users(:editor)
    UserPreferences.set!(user, "listings.posts.presets", [ { "handle" => "mine", "label" => "Mine", "query" => { "status" => "draft" } } ])
    assert_equal 1, UserPreferences.get(user, "listings.posts.presets").size

    assert_raises(UserPreferences::InvalidValue) { UserPreferences.set!(user, "listings.posts.presets", [ { "handle" => "mine" } ]) }
    assert_raises(UserPreferences::InvalidValue) { UserPreferences.set!(user, "listings.posts.presets", Array.new(11) { |i| { "handle" => i.to_s, "label" => "x", "query" => {} } }) }
  end

  test "dashboard.widgets is validated by shape" do
    user = users(:editor)

    UserPreferences.set!(user, "dashboard.widgets", [ { "type" => "quick_links", "width" => 33 } ])
    assert_equal [ { "type" => "quick_links", "width" => 33 } ], UserPreferences.get(user, "dashboard.widgets")

    assert_raises(UserPreferences::InvalidValue) { UserPreferences.set!(user, "dashboard.widgets", [ { "type" => "quick_links", "width" => 40 } ]) }
    assert_raises(UserPreferences::InvalidValue) { UserPreferences.set!(user, "dashboard.widgets", [ { "width" => 33 } ]) }
  end

  test "dashboard.widgets height is optional and must be a plain px or rem length" do
    user = users(:editor)
    UserPreferences.set!(user, "dashboard.widgets", [ { "type" => "quick_links", "width" => 33, "height" => "20rem" } ])
    assert_equal "20rem", UserPreferences.get(user, "dashboard.widgets").first["height"]

    UserPreferences.set!(user, "dashboard.widgets", [ { "type" => "quick_links", "width" => 33 } ])
    assert_not UserPreferences.get(user, "dashboard.widgets").first.key?("height"), "height is optional, absent means auto"

    UserPreferences.set!(user, "dashboard.widgets", [ { "type" => "quick_links", "width" => 33, "height" => nil } ])
    assert_nil UserPreferences.get(user, "dashboard.widgets").first["height"], "explicit nil also means auto"

    assert_raises(UserPreferences::InvalidValue) { UserPreferences.set!(user, "dashboard.widgets", [ { "type" => "quick_links", "width" => 33, "height" => "tall" } ]) }
    assert_raises(UserPreferences::InvalidValue) { UserPreferences.set!(user, "dashboard.widgets", [ { "type" => "quick_links", "width" => 33, "height" => "20vh" } ]) }
  end

  test "all merges every known key's default with the user's saved overrides" do
    user = users(:editor)
    UserPreferences.set!(user, "theme", "dark")

    all = UserPreferences.all(user)
    assert_equal "dark", all["theme"]
    assert_equal false, all["sidebar_collapsed"]
    assert_equal "grid", all["assets"]["view"], "a preference never touched still reports its default"
  end
end
