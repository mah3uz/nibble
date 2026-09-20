require "test_helper"

class Admin::ElevationScopeTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    Current.session.update!(elevated_at: 20.minutes.ago)
  end

  test "reading the screens never asks for the password again, so nobody is bounced mid-task" do
    get "/admin/users"
    assert_response :success
    get "/admin/users/#{users(:editor).id}/edit"
    assert_response :success
    get "/admin/roles"
    assert_response :success
    get "/admin/roles/#{roles(:editor).id}/edit"
    assert_response :success
    get "/admin/api-tokens"
    assert_response :success
  end

  test "changing anything still waits for the password" do
    patch "/admin/users/#{users(:editor).id}", params: { user: { name: "Renamed" } }
    assert_not_equal "Renamed", users(:editor).reload.name

    patch "/admin/roles/#{roles(:editor).id}", params: { role: { title: "Renamed" } }
    assert_not_equal "Renamed", roles(:editor).reload.title

    post "/admin/api-tokens", params: { api_token: { name: "Nope", scopes: %w[read] } }
    assert_equal 0, ApiToken.count
  end
end
