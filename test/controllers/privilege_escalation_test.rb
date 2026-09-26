require "test_helper"
require "webauthn/fake_client"

class PrivilegeEscalationTest < ActionDispatch::IntegrationTest
  def manager_of(ability)
    role = Role.create!(handle: "manager_#{ability.tr('.', '_')}", title: "Manager", abilities: [ ability ])
    users(:editor).tap { |user| user.roles = [ role ] }.reload
  end

  test "a role can't be given a bare wildcard, which would be full access by the back door" do
    sign_in_as manager_of("roles.manage")

    post "/cp/roles", params: { role: { title: "Backdoor", abilities: [ "*" ] } }

    assert_nil Role.find_by(handle: "backdoor")
  end

  test "an ability the editor never offered is refused, not quietly dropped" do
    sign_in_as users(:admin)

    post "/cp/roles", params: { role: { title: "Invented", abilities: %w[entries.posts.view made.up.ability] } }

    assert_nil Role.find_by(handle: "invented")
    assert_match "made.up.ability", session[:inertia_errors].to_h.with_indifferent_access[:abilities].to_s
  end

  test "full access is only ever handed on by someone who already has it" do
    sign_in_as manager_of("users.manage")

    patch "/cp/users/#{users(:author).id}", params: { user: { role_ids: [ roles(:admin).id ] } }

    assert_response :forbidden
    assert_not users(:author).reload.admin?
  end

  test "an administrator's account can't be edited or reset by someone below them" do
    sign_in_as manager_of("users.manage")

    patch "/cp/users/#{users(:admin).id}", params: { user: { email_address: "attacker@example.test" } }
    assert_response :forbidden
    assert_not_equal "attacker@example.test", users(:admin).reload.email_address

    post "/cp/users/#{users(:admin).id}/send_reset"
    assert_response :forbidden
  end
end
