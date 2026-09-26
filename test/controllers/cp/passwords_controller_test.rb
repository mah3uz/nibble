require "test_helper"

class Nibble::Cp::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_cp_password_path
    assert_response :success
  end

  test "create" do
    post cp_passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_cp_session_path

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  test "create for an unknown user redirects but sends no mail" do
    post cp_passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_cp_session_path

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  test "edit" do
    get edit_cp_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_cp_password_path("invalid token")
    assert_redirected_to new_cp_password_path

    follow_redirect!
    assert_notice "reset link is invalid"
  end

  test "update" do
    assert_changes -> { @user.reload.password_digest } do
      put cp_password_path(@user.password_reset_token), params: { password: "Test-Password-1", password_confirmation: "Test-Password-1" }
      assert_redirected_to new_cp_session_path
    end

    follow_redirect!
    assert_notice "Password has been reset"
  end

  test "a password shorter than the minimum is refused, so a reset can't weaken an account" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put cp_password_path(token), params: { password: "short", password_confirmation: "short" }
      assert_redirected_to edit_cp_password_path(token)
    end
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put cp_password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_cp_password_path(token)
    end

    follow_redirect!
    assert_notice "Passwords did not match"
  end

  private
    # Flash messages reach the Inertia page as props (shown as toasts).
    def assert_notice(text)
      page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
      assert_match(/#{text}/, page.dig("props", "flash").values.join(" "))
    end
end
