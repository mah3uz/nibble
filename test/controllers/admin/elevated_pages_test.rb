require "test_helper"

class Admin::ElevatedPagesTest < ActionDispatch::IntegrationTest
  def component = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["component"]

  setup do
    sign_in_as users(:admin)
    Current.session.update!(elevated_at: 20.minutes.ago)
  end

  test "screens that change who can do what ask who you are before they open" do
    [ "/admin/account/edit", "/admin/roles", "/admin/roles/new", "/admin/users", "/admin/api-tokens", "/admin/utilities/content" ].each do |path|
      get path
      assert_equal "admin/Confirm", component, "#{path} should ask for the password first"
    end
  end

  test "confirming the password opens the screen itself" do
    post "/admin/session/elevate", params: { password: "password" }, as: :json
    assert_response :success

    get "/admin/roles"
    assert_equal "admin/roles/Index", component
  end

  test "a save after the confirmation lapsed goes back to the screen, which asks again" do
    role = roles(:editor)
    patch "/admin/roles/#{role.id}", params: { role: { title: "Renamed" } }, headers: { "Referer" => "http://www.example.com/admin/roles/#{role.id}/edit" }

    assert_redirected_to "http://www.example.com/admin/roles/#{role.id}/edit"
    assert_not_equal "Renamed", role.reload.title
    follow_redirect!
    assert_equal "admin/Confirm", component
  end
end
