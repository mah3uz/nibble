require "test_helper"

class Nibble::Cp::DashboardControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  test "the dashboard shows what the team is working on, and the navigation follows the schema" do
    draft = create_entry("articles", { "title" => "Half written" }, actor: users(:editor))
    scheduled = create_entry("articles", { "title" => "Coming up" })
    lifecycle(scheduled, :publish, { "published_at" => 2.days.from_now.utc.iso8601 })

    get cp_root_path
    assert_response :success
    page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)

    assert_equal "cp/Dashboard", page["component"]
    assert_includes page["props"]["layout"].map { |widget| widget["type"] }, "recent_entries"
    assert_equal [ "Articles", "Docs", "Pages", "Posts", "Tags", "Assets" ],
      page["props"]["cp"]["nav"].find { |section| section["handle"] == "content" }["items"].map { |item| item["title"] }

    get cp_root_path, headers: { "X-Inertia" => "true", "X-Inertia-Version" => page["version"],
                                    "X-Inertia-Partial-Component" => "cp/Dashboard", "X-Inertia-Partial-Data" => "data" }
    widgets = response.parsed_body["props"]["data"]
    assert_includes widgets["scheduled"]["items"].map { |row| row["title"] }, "Coming up"
    assert_includes widgets["recent_entries"]["items"].map { |row| row["edit_url"] },
      "/cp/collections/articles/entries/#{draft.id}/edit"
  end

  test "signed-out visitors are sent to the sign-in page" do
    delete cp_session_path
    get cp_root_path
    assert_redirected_to new_cp_session_path
  end

  # The screen existed, but nothing in the Control Plane led to it.
  test "missing pages are reachable from the sidebar, under Redirects" do
    get cp_root_path
    page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
    redirects = page["props"]["cp"]["nav"].flat_map { |section| section["items"] }.find { |item| item["title"] == "Redirects" }

    assert_equal [ [ "Missing pages", "/cp/404s" ] ], redirects["children"].map { |child| child.values_at("title", "url") }
  end
end
