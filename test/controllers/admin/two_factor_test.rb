require "test_helper"

class Admin::TwoFactorTest < ActionDispatch::IntegrationTest
  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def props = page["props"]
  def code_for(user) = ROTP::TOTP.new(user.reload.totp_secret).now

  def enable_totp(user)
    user.start_totp_setup!
    user.confirm_totp(code_for(user))
    user.generate_recovery_codes!
  end

  test "a password alone doesn't sign in an account with two-factor on" do
    enable_totp(users(:admin))

    post "/admin/session", params: { email_address: users(:admin).email_address, password: "password" }

    assert_redirected_to "/admin/session/challenge"
    get "/admin"
    assert_redirected_to "/admin/session/new", "the password alone left them signed out"
  end

  test "a code from the authenticator finishes the sign-in, and can't be replayed" do
    enable_totp(users(:admin))
    travel 60.seconds
    code = code_for(users(:admin))
    post "/admin/session", params: { email_address: users(:admin).email_address, password: "password" }

    post "/admin/session/challenge", params: { code: }
    assert_redirected_to "/admin"

    delete "/admin/session"
    post "/admin/session", params: { email_address: users(:admin).email_address, password: "password" }
    post "/admin/session/challenge", params: { code: }
    assert_redirected_to "/admin/session/challenge", "a used code is refused"
  end

  test "a recovery code works once and is then spent" do
    codes = enable_totp(users(:admin))
    post "/admin/session", params: { email_address: users(:admin).email_address, password: "password" }

    post "/admin/session/challenge", params: { code: codes.first }
    assert_redirected_to "/admin"
    assert_equal codes.size - 1, users(:admin).reload.recovery_codes.size

    delete "/admin/session"
    post "/admin/session", params: { email_address: users(:admin).email_address, password: "password" }
    post "/admin/session/challenge", params: { code: codes.first }
    assert_redirected_to "/admin/session/challenge"
  end

  test "five wrong codes end the attempt, so a stolen password can't be brute-forced" do
    enable_totp(users(:admin))
    post "/admin/session", params: { email_address: users(:admin).email_address, password: "password" }

    5.times { post "/admin/session/challenge", params: { code: "000000" } }

    assert_redirected_to "/admin/session/new"
    post "/admin/session/challenge", params: { code: code_for(users(:admin)) }
    assert_redirected_to "/admin/session/new", "the pending sign-in is gone"
  end

  test "a role that requires two-factor holds the user on their account screen until it's on" do
    roles(:editor).update!(require_2fa: true)
    sign_in_as users(:editor)

    get "/admin/collections/posts"
    assert_redirected_to "/admin/account/edit"

    get "/admin/account/edit"
    assert_response :success
    assert props["two_factor"]["required"]
  end

  test "setting up two-factor shows the key once and turns on only after a correct code" do
    sign_in_as users(:editor)

    post "/admin/account/two_factor"
    follow_redirect!
    assert_not_nil props["two_factor"]["pending"]["secret"]
    assert_not props["two_factor"]["enabled"]

    get "/admin/account/edit"
    assert_nil props["two_factor"]["pending"], "an abandoned setup doesn't reopen on every visit"

    post "/admin/account/two_factor/confirm", params: { code: "000000" }
    follow_redirect!
    assert_not_nil props["two_factor"]["pending"], "a wrong code keeps the key on screen to try again"

    post "/admin/account/two_factor/confirm", params: { code: code_for(users(:editor)) }
    assert users(:editor).reload.totp?
    assert_equal TwoFactor::RECOVERY_CODE_COUNT, users(:editor).recovery_codes.size
  end

  test "turning two-factor off needs the password, and a role that requires it refuses" do
    enable_totp(users(:editor))
    sign_in_as users(:editor)

    delete "/admin/account/two_factor", params: { current_password: "wrong" }
    assert users(:editor).reload.totp?

    roles(:editor).update!(require_2fa: true)
    delete "/admin/account/two_factor", params: { current_password: "password" }
    assert users(:editor).reload.totp?

    roles(:editor).update!(require_2fa: false)
    delete "/admin/account/two_factor", params: { current_password: "password" }
    assert_not users(:editor).reload.totp?
  end
end
