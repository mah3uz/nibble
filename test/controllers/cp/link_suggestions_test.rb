require "test_helper"

class Nibble::Cp::LinkSuggestionsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  def suggestions = JSON.parse(response.body)["suggestions"]

  def publish(entry)
    lifecycle(entry, :submit)
    lifecycle(entry.reload, :approve)
    lifecycle(entry.reload, :publish)
    entry.reload
  end

  test "the link dialog suggests entries whose title or path matches what's typed" do
    wanted = publish(create_entry("docs", { "title" => "Pricing changes", "slug" => "pricing", "body" => "Body" }))
    publish(create_entry("docs", { "title" => "Something else", "slug" => "other", "body" => "Body" }))

    get "/cp/link_suggestions", params: { q: "/pric" }

    assert_equal [ "Pricing changes" ], suggestions.map { |item| item["title"] }
    assert_equal wanted.reload.uri, suggestions.first["path"], "the dialog inserts this straight into the href"
    assert_equal "published", suggestions.first["status"]
  end

  test "entries with no address of their own are never offered as links" do
    create_entry("articles", { "title" => "Unaddressed" })

    get "/cp/link_suggestions", params: { q: "unaddressed" }

    assert_empty suggestions, "a suggestion the editor can't turn into a working href is worse than none"
  end
end
