require "test_helper"

class Admin::RolesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def props = page["props"]

  test "only people who manage roles can see or change them" do
    sign_in_as users(:editor)
    get "/admin/roles"
    assert_response :forbidden

    post "/admin/roles", params: { role: { title: "Sneak" } }
    assert_response :forbidden
    assert_nil Role.find_by(handle: "sneak")
  end

  test "a role is created from the abilities that were checked, with a handle from its title" do
    post "/admin/roles", params: { role: { title: "News desk", abilities: %w[entries.posts.view entries.posts.edit] } }

    role = Role.find_by!(handle: "news_desk")
    assert_equal %w[entries.posts.view entries.posts.edit], role.abilities
    assert_not role.superuser?
    assert Nibble::Access.can?(users(:author).tap { |user| user.roles = [ role ] }, "entries.posts.edit")
  end

  test "saving a role keeps abilities for schema this site doesn't have, so a rename doesn't erase them" do
    role = Role.create!(handle: "keeper", title: "Keeper", abilities: %w[entries.archive.view entries.posts.view])

    patch "/admin/roles/#{role.id}", params: { role: { title: "Keeper", abilities: %w[entries.posts.edit] } }

    assert_equal %w[entries.posts.edit entries.archive.view], role.reload.abilities
  end

  test "the last role with full access keeps it, so nobody can lock everyone out" do
    patch "/admin/roles/#{roles(:admin).id}", params: { role: { title: "Administrator", superuser: "0", abilities: [] } }
    assert roles(:admin).reload.superuser?

    delete "/admin/roles/#{roles(:admin).id}"
    assert Role.exists?(roles(:admin).id)
  end

  test "turning on full access drops the ability list, since it grants everything" do
    role = Role.create!(handle: "second", title: "Second", abilities: %w[entries.posts.view])

    patch "/admin/roles/#{role.id}", params: { role: { title: "Second", superuser: "1", abilities: %w[entries.posts.view] } }

    assert_empty role.reload.abilities
    assert_equal %w[*], role.grants
  end

  test "someone who manages roles but isn't a superuser can't mint one" do
    manager = Role.create!(handle: "manager", title: "Manager", abilities: %w[roles.manage])
    sign_in_as users(:editor).tap { |user| user.roles = [ manager ] }

    get "/admin/roles/new"
    assert_not props["can_assign_superuser"]

    post "/admin/roles", params: { role: { title: "Backdoor", superuser: "1" } }
    assert_not Role.find_by!(handle: "backdoor").superuser?
  end

  test "the editor screen offers the site's own schema, so a new collection is grantable at once" do
    get "/admin/roles/#{roles(:editor).id}/edit"

    groups = props["groups"].to_h { |group| [ group["handle"], group ] }
    assert_equal Nibble.schema.collections.size + 1, groups["collections"]["abilities"].size
    assert_equal "entries.*", groups["collections"]["abilities"].first["value"]
  end
end
