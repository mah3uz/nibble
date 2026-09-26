require "test_helper"

class AuthHardeningTest < ActionDispatch::IntegrationTest
  Entry = Nibble::Records::AuditEntry

  setup { Rails.cache.clear }

  def sign_in(password: "password", email: users(:admin).email_address)
    post "/cp/session", params: { email_address: email, password: }
  end

  test "ten wrong passwords lock the address out, so a stolen list can't be tried one by one" do
    10.times { sign_in(password: "wrong") }
    assert_equal 10, Nibble::Lockout.failures(users(:admin).email_address)

    sign_in
    get "/cp"
    assert_redirected_to "/cp/session/new", "even the right password waits out the block"
    assert Entry.exists?(action: "auth.locked_out", subject_id: users(:admin).id)
  end

  test "the block lifts with the window, and a success clears the count" do
    9.times { sign_in(password: "wrong") }

    travel Nibble::Lockout::WINDOW + 1.minute
    sign_in
    assert_equal 0, Nibble::Lockout.failures(users(:admin).email_address)
    get "/cp"
    assert_response :success
  end

  test "signing in and out is recorded with the address it came from" do
    sign_in
    delete "/cp/session"

    assert_equal %w[auth.signed_in auth.signed_out], Entry.where(subject_id: users(:admin).id).order(:id).pluck(:action)
    assert_equal "127.0.0.1", Entry.find_by(action: "auth.signed_in").ip
  end

  test "a stale session can read the Control Plane but not change who can do what" do
    sign_in_as users(:admin)
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)

    get "/cp/roles"
    assert_response :success, "the listing is still readable"

    post "/cp/roles", params: { role: { title: "Sneaky" } }
    assert_nil Role.find_by(handle: "sneaky"), "changing roles waits for the password"

    patch "/cp/users/#{users(:editor).id}", params: { user: { name: "Renamed" } }
    assert_not_equal "Renamed", users(:editor).reload.name
  end

  test "confirming the password lifts the lock, and a wrong one doesn't" do
    sign_in_as users(:admin)
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)

    post "/cp/session/elevate", params: { password: "wrong" }
    assert_response :unauthorized

    post "/cp/session/elevate", params: { password: "password" }
    assert_response :success

    post "/cp/roles", params: { role: { title: "Allowed" } }
    assert Role.exists?(handle: "allowed")
    assert Entry.exists?(action: "auth.elevated", actor_id: users(:admin).id)
  end

  test "changing someone's roles is recorded with who did it" do
    sign_in_as users(:admin)

    patch "/cp/users/#{users(:author).id}", params: { user: { role_ids: [ roles(:editor).id ] } }

    entry = Entry.find_by!(action: "auth.roles_changed", subject_id: users(:author).id)
    assert_equal users(:admin).id, entry.changeset["by"]
    assert_equal [ %w[author], %w[editor] ], entry.changeset.values_at("from", "to")
  end

  test "turning two-factor on and off is recorded" do
    sign_in_as users(:editor)

    post "/cp/account/two_factor"
    post "/cp/account/two_factor/confirm", params: { code: ROTP::TOTP.new(users(:editor).reload.totp_secret).now }
    delete "/cp/account/two_factor", params: { current_password: "password" }

    assert_equal %w[auth.two_factor_enabled auth.two_factor_disabled],
      Entry.where(action: %w[auth.two_factor_enabled auth.two_factor_disabled]).order(:id).pluck(:action)
  end
end
