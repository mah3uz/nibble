require "test_helper"

class Nibble::Cp::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = Nibble::User.take }

  test "new" do
    get new_cp_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post cp_session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to cp_root_url
    assert cookies[:nibble_session_id]
  end

  test "create with invalid credentials" do
    post cp_session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_cp_session_path
    assert_nil cookies[:nibble_session_id]
  end

  test "destroy" do
    sign_in_as(Nibble::User.take)

    delete cp_session_path

    assert_redirected_to new_cp_session_path
    assert_empty cookies[:nibble_session_id]
  end
end
