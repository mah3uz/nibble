require "test_helper"

class Nibble::Cp::ElevatedPagesTest < ActionDispatch::IntegrationTest
  def component = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["component"]

  setup do
    sign_in_as users(:admin)
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)
  end

  test "screens that change who can do what ask who you are before they open" do
    [ "/cp/account/edit", "/cp/roles", "/cp/roles/new", "/cp/users", "/cp/api-tokens", "/cp/utilities/content" ].each do |path|
      get path
      assert_equal "cp/Confirm", component, "#{path} should ask for the password first"
    end
  end

  test "confirming the password opens the screen itself" do
    post "/cp/session/elevate", params: { password: "password" }, as: :json
    assert_response :success

    get "/cp/roles"
    assert_equal "cp/roles/Index", component
  end

  test "a save after the confirmation lapsed goes back to the screen, which asks again" do
    role = roles(:editor)
    patch "/cp/roles/#{role.id}", params: { role: { title: "Renamed" } }, headers: { "Referer" => "http://www.example.com/cp/roles/#{role.id}/edit" }

    assert_redirected_to "http://www.example.com/cp/roles/#{role.id}/edit"
    assert_not_equal "Renamed", role.reload.title
    follow_redirect!
    assert_equal "cp/Confirm", component
  end
end
