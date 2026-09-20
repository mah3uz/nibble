require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "a superuser role grants everything without listing abilities, so new features need no reseed" do
    assert_equal %w[*], roles(:admin).grants
    assert Nibble::Access.can?(users(:admin), "anything.at.all")
  end

  test "seeding the defaults twice leaves one of each, so db:seed stays safe to re-run" do
    Role.seed_defaults!
    Role.seed_defaults!

    assert_equal Role::DEFAULTS.map { |role| role[:handle] }.sort, Role.pluck(:handle).sort
  end

  test "seeding never rewrites a role an administrator has edited" do
    roles(:editor).update!(abilities: %w[entries.*.view])
    Role.seed_defaults!

    assert_equal %w[entries.*.view], roles(:editor).reload.abilities
  end

  test "the only administrator's role can't be taken away" do
    assert_not user_roles(:admin).destroy
    assert Nibble::Access.can?(users(:admin).reload, "users.manage")
  end

  test "a user's abilities are the union of their roles" do
    users(:author).roles << roles(:editor)

    assert Nibble::Access.can?(users(:author).reload, "entries.articles.publish")
  end
end
