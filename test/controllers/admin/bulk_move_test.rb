require "test_helper"

class Admin::BulkMoveTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

  test "a structured listing offers a move that asks where to" do
    guides = create_entry("docs", { "title" => "Guides" })

    get "/admin/collections/docs"
    move = props["listing"]["actions"].find { |action| action["handle"] == "move" }

    assert move, "moving several pages at once is the point of selecting them"
    options = move["fields"].first["options"].map { |option| option["label"] }
    assert_equal "Top level", options.first
    assert_includes options, "Guides"
    assert_includes props["listing"]["rows"].find { |row| row["id"] == guides.id }["actions"], "move"
  end

  test "an undated, unstructured listing doesn't offer a move it can't perform" do
    get "/admin/collections/articles"
    assert_not_includes props["listing"]["actions"].map { |action| action["handle"] }, "move"
  end

  test "selected entries move under the chosen parent, and back to the top" do
    guides = create_entry("docs", { "title" => "Guides" })
    setup = create_entry("docs", { "title" => "Setup" })
    faq = create_entry("docs", { "title" => "FAQ" })

    post "/admin/actions", params: { resource: "collections.docs", handle: "move", ids: [ setup.id, faq.id ],
                                     values: { parent_id: guides.id.to_s } }
    assert_equal [ guides.id, guides.id ], [ setup.reload.parent_id, faq.reload.parent_id ]

    post "/admin/actions", params: { resource: "collections.docs", handle: "move", ids: [ setup.id ],
                                     values: { parent_id: Nibble::Cp::Listing::TOP_LEVEL } }
    assert_nil setup.reload.parent_id, "the top of the tree has to be reachable too"
  end

  test "a move with nowhere chosen changes nothing" do
    setup = create_entry("docs", { "title" => "Setup" })

    post "/admin/actions", params: { resource: "collections.docs", handle: "move", ids: [ setup.id ], values: {} }

    assert_response :bad_request
    assert_nil setup.reload.parent_id
  end
end
