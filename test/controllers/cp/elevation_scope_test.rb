require "test_helper"

class Nibble::Cp::ElevationScopeTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)
  end

  test "reading the screens never asks for the password again, so nobody is bounced mid-task" do
    get "/cp/users"
    assert_response :success
    get "/cp/users/#{users(:editor).id}/edit"
    assert_response :success
    get "/cp/roles"
    assert_response :success
    get "/cp/roles/#{roles(:editor).id}/edit"
    assert_response :success
    get "/cp/api-tokens"
    assert_response :success
  end

  test "changing anything still waits for the password" do
    patch "/cp/users/#{users(:editor).id}", params: { user: { name: "Renamed" } }
    assert_not_equal "Renamed", users(:editor).reload.name

    patch "/cp/roles/#{roles(:editor).id}", params: { role: { title: "Renamed" } }
    assert_not_equal "Renamed", roles(:editor).reload.title

    post "/cp/api-tokens", params: { api_token: { name: "Nope", scopes: %w[read] } }
    assert_equal 0, ApiToken.count
  end
end
