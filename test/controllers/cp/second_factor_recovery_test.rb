require "test_helper"
require "webauthn/fake_client"

class Nibble::Cp::SecondFactorRecoveryTest < ActionDispatch::IntegrationTest
  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def props = page["props"]

  def register_passkey(user)
    sign_in_as user
    client = WebAuthn::FakeClient.new(Nibble.config.url)
    post "/cp/account/passkeys/options"
    post "/cp/account/passkeys",
      params: { name: "Key", credential: client.create(challenge: JSON.parse(response.body)["challenge"], user_verified: true) }
    client
  end

  test "a passkey also earns recovery codes, so a lost device isn't a locked account" do
    register_passkey(users(:editor))

    assert_equal TwoFactor::RECOVERY_CODE_COUNT, users(:editor).reload.recovery_codes.size
    get "/cp/account/edit"
    assert_equal TwoFactor::RECOVERY_CODE_COUNT, props["two_factor"]["recovery_codes"].size
  end

  test "recovery codes stay on screen until they're acknowledged, so a reload doesn't lose them" do
    register_passkey(users(:editor))

    get "/cp/account/edit"
    assert_not_nil props["two_factor"]["recovery_codes"]

    post "/cp/account/two_factor/recovery_codes/ack"
    get "/cp/account/edit"
    assert_nil props["two_factor"]["recovery_codes"]
  end

  test "turning the authenticator app off leaves passkeys signing you in" do
    register_passkey(users(:editor))
    users(:editor).start_totp_setup!
    users(:editor).confirm_totp(ROTP::TOTP.new(users(:editor).totp_secret).now)

    delete "/cp/account/two_factor", params: { current_password: "password" }

    assert_not users(:editor).reload.totp?
    assert users(:editor).two_factor?, "the passkey still stands between a password and the CP"
  end

  test "the last way in can't be removed while a role insists on two-factor" do
    register_passkey(users(:editor))
    roles(:editor).update!(require_2fa: true)

    delete "/cp/account/passkeys/#{users(:editor).user_credentials.sole.id}"

    assert_equal 1, users(:editor).reload.user_credentials.count
  end

  test "a passkey the authenticator didn't verify is refused at registration too" do
    sign_in_as users(:editor)
    client = WebAuthn::FakeClient.new(Nibble.config.url)
    post "/cp/account/passkeys/options"

    post "/cp/account/passkeys",
      params: { name: "Key", credential: client.create(challenge: JSON.parse(response.body)["challenge"], user_verified: false) }

    assert_response :unprocessable_content
    assert_equal 0, users(:editor).user_credentials.count
  end
end
