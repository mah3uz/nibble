require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in_as users(:admin) }

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def props = page["props"]

  test "only people who manage users can reach the screens or change anyone" do
    sign_in_as users(:editor)

    get "/admin/users"
    assert_response :forbidden

    patch "/admin/users/#{users(:author).id}", params: { user: { role_ids: [ roles(:admin).id ] } }
    assert_response :forbidden
    assert_not users(:author).reload.admin?
  end

  test "inviting someone sends the set-password link instead of a password nobody chose" do
    assert_enqueued_emails 1 do
      post "/admin/users", params: { user: { name: "Ada", email_address: "Ada@Example.test", role_ids: [ roles(:author).id ] } }
    end

    invited = User.find_by!(email_address: "ada@example.test")
    assert_equal [ "author" ], invited.roles.map(&:handle)
    assert_nil invited.last_login_at
    assert User.find_by_token_for(:invitation, invited.generate_token_for(:invitation))
  end

  test "nobody edits their own roles, so an administrator can't quietly demote or promote themselves" do
    patch "/admin/users/#{users(:admin).id}", params: { user: { name: "Renamed", role_ids: [ roles(:author).id ] } }

    assert_equal "Renamed", users(:admin).reload.name
    assert_equal [ "admin" ], users(:admin).roles.map(&:handle)
  end

  test "a user can hold several roles and gets the union of them" do
    patch "/admin/users/#{users(:author).id}", params: { user: { role_ids: [ roles(:author).id, roles(:editor).id ] } }

    assert Nibble::Access.can?(users(:author).reload, "entries.posts.publish")
  end

  test "signing in records the last sign-in the listing shows" do
    post "/admin/session", params: { email_address: users(:editor).email_address, password: "password" }
    sign_in_as users(:admin)

    get "/admin/users"
    row = props["listing"]["rows"].find { |item| item["email_address"] == users(:editor).email_address }
    assert_not_nil row["last_login_at"]
  end

  test "the listing filters by role and searches names and addresses" do
    get "/admin/users", params: { role: "author" }
    assert_equal [ users(:author).email_address ], props["listing"]["rows"].map { |row| row["email_address"] }

    get "/admin/users", params: { q: "EDITOR@" }
    assert_equal [ users(:editor).email_address ], props["listing"]["rows"].map { |row| row["email_address"] }
  end

  test "revoking a session signs that browser out at once" do
    session = users(:editor).sessions.create!(user_agent: "Test", ip_address: "127.0.0.1")

    delete "/admin/users/#{users(:editor).id}/sessions/#{session.id}"

    assert_not Session.exists?(session.id)
  end

  test "an administrator can't delete their own account" do
    delete "/admin/users/#{users(:admin).id}"

    assert_response :forbidden
    assert User.exists?(users(:admin).id)
  end
end
