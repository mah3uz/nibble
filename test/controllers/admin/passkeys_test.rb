require "test_helper"
require "webauthn/fake_client"

class Admin::PasskeysTest < ActionDispatch::IntegrationTest
  def client = @client ||= WebAuthn::FakeClient.new(Nibble.config.url)
  def json = JSON.parse(response.body)

  def register(name: "Laptop")
    post "/admin/account/passkeys/options"
    credential = client.create(challenge: json["challenge"], user_verified: true)
    post "/admin/account/passkeys", params: { name:, credential: }
  end

  test "a registered passkey belongs to the person who registered it" do
    sign_in_as users(:editor)

    register

    assert_response :created
    credential = users(:editor).user_credentials.sole
    assert_equal "Laptop", credential.name
    assert users(:editor).reload.two_factor?, "a passkey counts as a second factor"
  end

  test "a lapsed elevation answers the passkey request in JSON so the dialog can say what to do" do
    sign_in_as users(:editor)

    travel Authentication::ELEVATION_WINDOW + 1.minute do
      post "/admin/account/passkeys/options", headers: { "Accept" => "application/json" }
    end

    assert_response :forbidden
    assert_equal "Confirm your password to carry on.", json["error"]
  end

  test "a passkey signs someone in without their password" do
    sign_in_as users(:editor)
    register
    sign_out

    post "/admin/session/passkey/options"
    assertion = client.get(challenge: json["challenge"], user_verified: true)
    post "/admin/session/passkey", params: { credential: assertion }

    assert_response :success
    assert_equal "http://www.example.com/admin", json["redirect"]
    get "/admin"
    assert_response :success
    assert_not_nil users(:editor).user_credentials.sole.last_used_at
  end

  test "a passkey answers the two-factor challenge, so an authenticator app isn't the only way back in" do
    sign_in_as users(:editor)
    register
    users(:editor).start_totp_setup!
    users(:editor).confirm_totp(ROTP::TOTP.new(users(:editor).totp_secret).now)
    sign_out

    post "/admin/session", params: { email_address: users(:editor).email_address, password: "password" }
    assert_redirected_to "/admin/session/challenge"

    post "/admin/session/passkey/options"
    assertion = client.get(challenge: json["challenge"], user_verified: true)
    post "/admin/session/passkey", params: { credential: assertion }

    get "/admin"
    assert_response :success
  end

  test "a challenge can't be replayed, and an unknown credential is refused" do
    sign_in_as users(:editor)
    register
    sign_out

    post "/admin/session/passkey/options"
    assertion = client.get(challenge: json["challenge"], user_verified: true)
    post "/admin/session/passkey", params: { credential: assertion }
    delete "/admin/session"

    post "/admin/session/passkey", params: { credential: assertion }
    assert_response :unauthorized

    post "/admin/session/passkey/options"
    stranger = WebAuthn::FakeClient.new(Nibble.config.url)
    stranger.create(challenge: json["challenge"], user_verified: true)
    post "/admin/session/passkey", params: { credential: stranger.get(challenge: json["challenge"], user_verified: true) }
    assert_response :unauthorized
  end

  test "someone can only remove their own passkeys" do
    sign_in_as users(:editor)
    register
    credential = users(:editor).user_credentials.sole

    sign_in_as users(:author)
    delete "/admin/account/passkeys/#{credential.id}"

    assert_response :not_found
    assert UserCredential.exists?(credential.id)
  end
end
