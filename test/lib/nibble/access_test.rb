require "test_helper"

class Nibble::AccessTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def can?(role, ability, record = nil) = Nibble::Access.can?(users(role), ability, record)

  test "an administrator can do everything, and a signed-out visitor nothing" do
    assert can?(:admin, "entries.articles.publish")
    assert can?(:admin, "users.manage")
    assert_not Nibble::Access.can?(nil, "entries.articles.view")
  end

  test "wildcards match one segment each, so an ability is never granted by accident" do
    assert can?(:editor, "entries.articles.publish")
    assert can?(:editor, "globals.site.edit")
    assert_not can?(:editor, "users.manage"), "editors don't manage users"
    assert_not can?(:author, "entries.articles.publish")
  end

  test "an author may edit only their own entries" do
    mine = create_entry("articles", { "title" => "Mine" }, actor: users(:author))
    theirs = create_entry("articles", { "title" => "Theirs" }, actor: users(:editor))

    assert can?(:author, "entries.articles.edit", mine)
    assert_not can?(:author, "entries.articles.edit", theirs)
    assert_not can?(:author, "entries.articles.edit"), "without a record there is nothing to own"
  end
end
