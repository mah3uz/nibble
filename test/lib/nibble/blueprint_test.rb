require "test_helper"
require_relative "../../test_helpers/nibble_schema_helper"

class Nibble::BlueprintTest < ActiveSupport::TestCase
  include NibbleSchemaHelper

  setup { register_fake_fieldtypes }
  teardown { unregister_fake_fieldtypes }

  def blueprint(tabs)
    item = schema_item("blueprints", "post", { title: "Post", tabs: }, parent: "collections/posts")
    Nibble::Blueprint.new(item, schema: Nibble::Schema.new([ item ]))
  end

  test "tabs and sections keep their order and all fields are reachable by handle" do
    result = blueprint(
      main: { display: "Content", sections: [ { display: "Basics", fields: [ { handle: "title", field: { type: "fake_text" } } ] } ] },
      sidebar: { sections: [ { fields: [ { handle: "count", field: { type: "fake_integer" } } ] } ] }
    )

    assert_equal %w[main sidebar], result.tabs.map(&:handle)
    assert_equal "Sidebar", result.tabs.last.display
    assert_equal %w[title count], result.fields.handles

    publish = result.to_publish_h
    assert_equal "Basics", publish["tabs"].first["sections"].first["display"]
    assert_equal "count", publish["tabs"].last["sections"].first["fields"].first["handle"]
  end

  test "the same handle in two tabs would store two values in one key, so it's rejected" do
    error = assert_raises(Nibble::SchemaError) do
      blueprint(
        main: { sections: [ { fields: [ { handle: "title", field: { type: "fake_text" } } ] } ] },
        sidebar: { sections: [ { fields: [ { handle: "title", field: { type: "fake_text" } } ] } ] }
      )
    end
    assert_match "field 'title' is already defined in tabs.main", error.message
  end
end
