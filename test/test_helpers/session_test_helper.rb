module SessionTestHelper
  def sign_in_as(user)
    Nibble::Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:nibble_session_id] = Nibble::Current.session.id
      cookies["nibble_session_id"] = cookie_jar[:nibble_session_id]
    end
  end

  def sign_out
    Nibble::Current.session&.destroy!
    cookies.delete("nibble_session_id")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
