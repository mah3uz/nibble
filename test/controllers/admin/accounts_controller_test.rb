require "test_helper"

class Admin::AccountsControllerTest < ActionDispatch::IntegrationTest
  def errors = session[:inertia_errors].to_h.with_indifferent_access

  test "renaming yourself" do
    sign_in_as users(:editor)
    patch admin_account_path, params: { user: { name: "New Name" } }
    assert_redirected_to edit_admin_account_path
    assert_equal "New Name", users(:editor).reload.name
  end

  test "a blank name is rejected" do
    sign_in_as users(:editor)
    patch admin_account_path, params: { user: { name: "" } }
    assert_redirected_to edit_admin_account_path
    assert_match "blank", errors[:name]
    assert_equal "Editor User", users(:editor).reload.name
  end

  test "changing your password requires the current one" do
    sign_in_as users(:editor)
    patch admin_account_path, params: { user: { current_password: "wrong", password: "Test-Password-1", password_confirmation: "Test-Password-1" } }
    assert_redirected_to edit_admin_account_path
    assert_equal "is incorrect", errors[:current_password]
    assert users(:editor).reload.authenticate("password"), "the password must be unchanged"
  end

  test "changing your password signs out every other session but keeps this one" do
    editor = users(:editor)
    sign_in_as editor
    other_session = editor.sessions.create!(user_agent: "Other browser", ip_address: "1.2.3.4")
    this_session = Current.session

    patch admin_account_path, params: { user: { current_password: "password", password: "Test-Password-1", password_confirmation: "Test-Password-1" } }
    assert_redirected_to edit_admin_account_path

    assert editor.reload.authenticate("Test-Password-1")
    assert Session.exists?(this_session.id), "the session making the change must stay signed in"
    assert_not Session.exists?(other_session.id), "a stolen session dies with a password change"
  end

  test "mismatched confirmation is refused" do
    sign_in_as users(:editor)
    patch admin_account_path, params: { user: { current_password: "password", password: "Test-Password-1", password_confirmation: "does-not-match" } }
    assert_redirected_to edit_admin_account_path
    assert_match "match", errors[:password_confirmation]
    assert users(:editor).reload.authenticate("password"), "the password must be unchanged"
  end

  test "the start page is a collection that exists, and signing in lands there" do
    UserPreferences.set!(users(:editor), "start_page", "posts")

    post "/admin/session", params: { email_address: users(:editor).email_address, password: "password" }
    assert_redirected_to "http://www.example.com/admin/collections/posts"

    assert_raises(UserPreferences::InvalidValue, "a listing that isn't in the schema can't be landed on") do
      UserPreferences.set!(users(:editor), "start_page", "media")
    end
  end
end
