require "test_helper"

class Nibble::Cp::PathTest < ActionDispatch::IntegrationTest
  test "the Control Plane is at /cp, and asks for sign-in there" do
    get "/cp"
    assert_redirected_to "/cp/session/new"

    sign_in_as users(:admin)
    get "/cp"
    assert_response :success
  end

  test "/admin is no longer Nibble's, so a site's content may have it" do
    assert_not_includes Nibble::Config::RESERVED_PATHS, "/admin"

    get "/admin"
    assert_response :not_found
  end
end
