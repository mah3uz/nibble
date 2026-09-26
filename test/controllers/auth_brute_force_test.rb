require "test_helper"
require "webauthn/fake_client"

class AuthBruteForceTest < ActionDispatch::IntegrationTest
  setup do
    users(:admin).start_totp_setup!
    users(:admin).confirm_totp(ROTP::TOTP.new(users(:admin).totp_secret).now)
    travel 60.seconds
  end

  def sign_in = post("/cp/session", params: { email_address: users(:admin).email_address, password: "password" })

  test "wrong codes are counted for the account, so signing in again buys no fresh guesses" do
    2.times do
      sign_in
      5.times { post "/cp/session/challenge", params: { code: "000000" } }
    end
    assert_equal 10, Nibble::Lockout.failures(users(:admin).email_address, kind: "code"),
      "the count survives starting the sign-in over"
    assert_not Nibble::Lockout.locked?(users(:admin).email_address), "a mistyped code or two isn't a lockout"

    2.times do
      sign_in
      5.times { post "/cp/session/challenge", params: { code: "000000" } }
    end
    assert Nibble::Lockout.locked?(users(:admin).email_address)

    sign_in
    post "/cp/session/challenge", params: { code: ROTP::TOTP.new(users(:admin).reload.totp_secret).now }
    get "/cp"
    assert_redirected_to "/cp/session/new", "a locked-out account stays out even with the right code"
  end

  test "the elevation dialog is not a password oracle" do
    sign_in_as users(:editor)
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)

    Nibble::Lockout::ATTEMPTS.times { post "/cp/session/elevate", params: { password: "guess" } }
    assert Nibble::Lockout.locked?(users(:editor).email_address)

    post "/cp/session/elevate", params: { password: "password" }
    assert_response :too_many_requests

    post "/cp/roles", params: { role: { title: "Still shut out" } }
    assert_nil Role.find_by(handle: "still_shut_out")
  end

  test "a passkey that didn't verify the person is refused" do
    sign_in_as users(:editor)
    client = WebAuthn::FakeClient.new(Nibble.config.url)
    post "/cp/account/passkeys/options"
    post "/cp/account/passkeys", params: { name: "Key", credential: client.create(challenge: JSON.parse(response.body)["challenge"], user_verified: true) }
    delete "/cp/session"

    post "/cp/session/passkey/options"
    post "/cp/session/passkey",
      params: { credential: client.get(challenge: JSON.parse(response.body)["challenge"], user_verified: false) }

    assert_response :unauthorized
    get "/cp"
    assert_redirected_to "/cp/session/new"
  end
end
