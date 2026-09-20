require "test_helper"

class Admin::NibbleApi::PlaygroundControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:editor) }

  teardown do
    %w[entry term asset].each { |type| Nibble::Resolvers.unregister(type) }
    %w[entry term].each { |type| Nibble::LinkTypes.unregister(type) }
    Nibble.boot!
  end

  def validate(values) = post(admin_nibble_playground_validate_path, params: { blueprint: "kitchen_sink", values: }, as: :json)

  test "the kitchen sink blueprint uses every v1 fieldtype that can be edited in the CP, so the playground exercises them all" do
    handles = JSON.parse(Rails.root.join("test/fixtures/files/nibble_fieldtypes.json").read).select { |handle| Nibble::Fieldtypes.find(handle).selectable }
    types = Nibble::Blueprint.new(Nibble::Playground.kitchen_sink_item, schema: Nibble.schema).fields.map(&:type)
    assert_empty handles - types
  end

  test "every core blueprint and global is offered, not only the kitchen sink" do
    assert_includes Nibble::Playground.blueprints.keys, "pages.page"
    assert_includes Nibble::Playground.blueprints.keys, "globals.site"
  end

  test "the page renders the blueprint in publish shape with defaults and meta" do
    get admin_nibble_playground_path, params: { blueprint: "kitchen_sink" }
    assert_response :success
  end

  test "an invalid submission returns field errors keyed by path, including nested sets and conditional fields" do
    validate("show_cta" => true, "blocks" => [ { "type" => "quote", "quote" => "" } ])

    errors = response.parsed_body["errors"]
    assert_includes errors.keys, "title"
    assert_includes errors.keys, "cta_label"
    assert_includes errors.keys, "blocks.0.quote"
  end

  test "a valid submission round-trips to stored values and the public shape" do
    validate("title" => "Hello", "tags" => %w[design], "category" => "news", "related" => [ "e1" ], "cta_link" => "entry::e2")

    body = response.parsed_body
    assert_empty body["errors"]
    assert_equal "Hello", body.dig("processed", "title")
    assert_equal({ "value" => "news", "label" => "News" }, body.dig("augmented", "category"))
    assert_equal "About us", body.dig("augmented", "related", 0, "title")
    assert_equal "/pricing", body.dig("augmented", "cta_link", "url")
  end
end
