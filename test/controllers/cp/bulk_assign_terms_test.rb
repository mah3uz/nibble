require "test_helper"

class Nibble::Cp::BulkAssignTermsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

  test "a listing offers adding each of its taxonomies' terms" do
    create_term("Pricing")
    create_entry("articles", { "title" => "Tagged later" })

    get "/cp/collections/articles"
    assign = props["listing"]["actions"].find { |action| action["handle"] == "assign_tags" }

    assert_equal "Add tag", assign&.dig("label")
    assert_equal [ "Pricing" ], assign["fields"].first["options"].map { |option| option["label"] }
    assert_includes props["listing"]["rows"].first["actions"], "assign_tags"
  end

  test "the chosen term reaches every selected entry" do
    tag = create_term("Pricing")
    first = create_entry("articles", { "title" => "One" })
    second = create_entry("articles", { "title" => "Two" })

    post "/cp/actions", params: { resource: "collections.articles", handle: "assign_tags",
                                     ids: [ first.id, second.id ], values: { term_ids: tag.id.to_s } }

    assert_equal [ [ tag.id.to_s ], [ tag.id.to_s ] ], [ first.reload.data["tags"], second.reload.data["tags"] ]
  end

  test "an assignment with no term chosen changes nothing" do
    article = create_entry("articles", { "title" => "Untouched" })

    post "/cp/actions", params: { resource: "collections.articles", handle: "assign_tags", ids: [ article.id ], values: {} }

    assert_response :bad_request
    assert_nil article.reload.data["tags"]
  end
end
