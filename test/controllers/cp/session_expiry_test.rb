require "test_helper"

class Nibble::Cp::SessionExpiryTest < ActionDispatch::IntegrationTest
  def json = { "Accept" => "application/json" }
  def idle = Nibble.config.session_idle

  test "an idle session ends on the server, so reloading the page asks for sign-in instead of walking back in" do
    sign_in_as users(:editor)
    session = Nibble::Current.session

    travel idle + 1.minute do
      get "/cp"

      assert_redirected_to "/cp/session/new"
      assert_not Nibble::Session.exists?(session.id), "an expired session that survives can be resumed with its cookie"
    end
  end

  test "working in the Control Plane keeps the session alive" do
    sign_in_as users(:editor)

    travel idle - 1.minute
    get "/cp"
    assert_response :success

    travel 2.minutes
    get "/cp"
    assert_response :success, "the clock runs from the last request, not from signing in"
  end

  test "asking how long is left doesn't count as activity, or an open tab would never time out" do
    sign_in_as users(:editor)

    travel idle - 2.minutes
    get "/cp/session/timeout", headers: json
    assert_in_delta 120, response.parsed_body["remaining"], 1

    travel 3.minutes
    get "/cp/session/timeout", headers: json
    assert_response :unauthorized
  end

  test "extending the session restarts its clock" do
    sign_in_as users(:editor)

    travel idle - 1.minute
    post "/cp/session/extend", headers: json
    assert_in_delta idle.to_i, response.parsed_body["remaining"], 1

    travel 2.minutes
    get "/cp"
    assert_response :success
  end

  test "a site sets how long a session may sit idle" do
    Nibble.config = Nibble::Config.new(Nibble.config_values.merge("session" => { "idle_minutes" => 5 }))
    sign_in_as users(:editor)

    travel 6.minutes do
      get "/cp"
      assert_redirected_to "/cp/session/new"
    end
  ensure
    Nibble.config = nil
  end

  test "signing back in answers in JSON, so the dialog keeps the unsaved page it covers" do
    post "/cp/session", params: { email_address: users(:editor).email_address, password: "wrong" }, headers: json
    assert_response :unprocessable_entity
    assert_match "password", response.parsed_body["error"]

    post "/cp/session", params: { email_address: users(:editor).email_address, password: "password" }, headers: json
    assert_equal({ "ok" => true }, response.parsed_body)
    assert cookies[:nibble_session_id]
  end

  test "an account with two-factor on is asked for its code in the dialog, not sent to another page" do
    user = users(:admin)
    user.start_totp_setup!
    user.confirm_totp(ROTP::TOTP.new(user.reload.totp_secret).now)

    post "/cp/session", params: { email_address: user.email_address, password: "password" }, headers: json
    assert_equal({ "two_factor" => true }, response.parsed_body)
    assert_nil cookies[:nibble_session_id].presence

    post "/cp/session/challenge", params: { code: "000000" }, headers: json
    assert_response :unprocessable_entity

    travel 31.seconds
    post "/cp/session/challenge", params: { code: ROTP::TOTP.new(user.reload.totp_secret).now }, headers: json
    assert_equal({ "ok" => true }, response.parsed_body)
  end
end
