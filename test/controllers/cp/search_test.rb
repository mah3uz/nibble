require "test_helper"

class Nibble::Cp::SearchTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  def groups = JSON.parse(response.body)["groups"]

  test "the palette finds records by title, drafts included" do
    draft = create_entry("articles", { "title" => "Pricing rewrite" })

    get "/cp/search", params: { q: "pricing" }

    articles = groups.find { |group| group["label"] == "Articles" }
    assert_equal [ "Pricing rewrite" ], articles["items"].map { |item| item["title"] },
                 "the palette is for jumping to a record you're working on, which is usually unpublished"
    assert_equal "/cp/collections/articles/entries/#{draft.id}/edit", articles["items"].first["url"]
    assert_equal "draft", articles["items"].first["status"]
  end

  test "trashed records are not offered" do
    entry = create_entry("articles", { "title" => "Thrown away" })
    lifecycle(entry, :trash)

    get "/cp/search", params: { q: "thrown" }

    assert_empty groups, "jumping to a trashed record would open an editor for something that isn't there"
  end

  test "an empty term returns nothing rather than everything" do
    create_entry("articles", { "title" => "Anything" })

    get "/cp/search", params: { q: "  " }

    assert_empty groups
  end
end
