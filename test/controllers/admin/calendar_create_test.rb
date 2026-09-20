require "test_helper"

class Admin::CalendarCreateTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  test "adding an entry from a calendar day prefills that day as the publish date" do
    get "/admin/collections/articles/entries/new", params: { date: "2026-08-04" }
    props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

    assert_equal "2026-08-04 09:00", Time.zone.parse(props["values"]["published_at"]).strftime("%Y-%m-%d %H:%M")
  end

  test "adding an entry from a calendar hour prefills that hour" do
    get "/admin/collections/articles/entries/new", params: { date: "2026-08-04T14:00" }
    props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

    assert_equal "2026-08-04 14:00", Time.zone.parse(props["values"]["published_at"]).strftime("%Y-%m-%d %H:%M")
  end
end
