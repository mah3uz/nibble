require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  test "the dashboard shows what the team is working on, and the navigation follows the schema" do
    draft = create_entry("articles", { "title" => "Half written" }, actor: users(:editor))
    scheduled = create_entry("articles", { "title" => "Coming up" })
    lifecycle(scheduled, :publish, { "published_at" => 2.days.from_now.utc.iso8601 })

    get admin_root_path
    assert_response :success
    page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)

    assert_equal "admin/Dashboard", page["component"]
    assert_includes page["props"]["layout"].map { |widget| widget["type"] }, "recent_entries"
    assert_equal [ "Articles", "Docs", "Pages", "Posts", "Tags", "Assets" ],
      page["props"]["admin"]["nav"].find { |section| section["handle"] == "content" }["items"].map { |item| item["title"] }

    get admin_root_path, headers: { "X-Inertia" => "true", "X-Inertia-Version" => page["version"],
                                    "X-Inertia-Partial-Component" => "admin/Dashboard", "X-Inertia-Partial-Data" => "data" }
    widgets = response.parsed_body["props"]["data"]
    assert_includes widgets["scheduled"]["items"].map { |row| row["title"] }, "Coming up"
    assert_includes widgets["recent_entries"]["items"].map { |row| row["edit_url"] },
      "/admin/collections/articles/entries/#{draft.id}/edit"
  end

  test "signed-out visitors are sent to the sign-in page" do
    delete session_path
    get admin_root_path
    assert_redirected_to new_session_path
  end
end
