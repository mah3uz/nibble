require "test_helper"
require_relative "../../test_helpers/nibble_schema_helper"

class Nibble::FieldsTest < ActiveSupport::TestCase
  include NibbleSchemaHelper

  setup { register_fake_fieldtypes }
  teardown { unregister_fake_fieldtypes }

  def schema(*items) = Nibble::Schema.new(items)

  def seo_fieldset
    schema_item("fieldsets", "nibble::seo", title: "SEO", fields: [
      { handle: "title", field: { type: "fake_text", character_limit: 60 } },
      { handle: "description", field: { type: "fake_text" } }
    ])
  end

  def fields(items, schema: schema(seo_fieldset))
    Nibble::Fields.new(items, schema:, source: "/schema/blueprints/test.yml", key: "fields")
  end

  test "an imported fieldset brings all its fields, with a prefix and per-field overrides" do
    result = fields([ { import: "nibble::seo", prefix: "seo_", config: { title: { character_limit: 70 } } } ])

    assert_equal %w[seo_title seo_description], result.handles
    assert_equal 70, result.get("seo_title").get("character_limit")
    assert_equal "seo_", result.get("seo_title").prefix
  end

  test "a single fieldset field can be referenced under a new handle with overrides" do
    result = fields([ { handle: "headline", field: "nibble::seo.title", config: { display: "Headline" } } ])

    headline = result.get("headline")
    assert_equal "Headline", headline.display
    assert_equal 60, headline.get("character_limit"), "the fieldset's own config is kept"
  end

  test "import loops are caught instead of hanging schema load" do
    a = schema_item("fieldsets", "a", title: "A", fields: [ { import: "b" } ])
    b = schema_item("fieldsets", "b", title: "B", fields: [ { import: "a" } ])

    error = assert_raises(Nibble::SchemaError) { fields([ { import: "a" } ], schema: schema(a, b)) }
    assert_match "fieldset import loop: a → b → a", error.message
  end

  test "mistakes are reported with the key path so authors find the exact field" do
    assert_raises(Nibble::SchemaError, match: /fields\.1: duplicate field handle 'title'/) do
      fields([ { handle: "title", field: { type: "fake_text" } }, { handle: "title", field: { type: "fake_text" } } ])
    end
    assert_raises(Nibble::SchemaError, match: /fields\.0\.field\.type: unknown fieldtype 'wysiwyg'/) do
      fields([ { handle: "body", field: { type: "wysiwyg" } } ])
    end
    assert_raises(Nibble::SchemaError, match: /fields\.0: no fieldset 'missing'/) { fields([ { import: "missing" } ]) }
    assert_raises(Nibble::SchemaError, match: /fieldset 'nibble::seo' has no field 'slug'/) do
      fields([ { handle: "slug", field: "nibble::seo.slug" } ])
    end
  end

  test "options a fieldtype doesn't declare are rejected, so typos in config never silently do nothing" do
    assert_raises(Nibble::SchemaError, match: /fields\.0\.field\.charcter_limit: isn't an option of the fake_text fieldtype/) do
      fields([ { handle: "title", field: { type: "fake_text", charcter_limit: 10 } } ])
    end
    assert_raises(Nibble::SchemaError, match: /fields\.0\.field\.width: has an invalid value: 40/) do
      fields([ { handle: "title", field: { type: "fake_text", width: 40 } } ])
    end
  end

  test "extensions can add options to an existing fieldtype" do
    NibbleFakes::FakeText.append_config_fields("autocomplete" => { "type" => "fake_text" })
    assert fields([ { handle: "name", field: { type: "fake_text", autocomplete: "name" } } ]).get("name")
  ensure
    NibbleFakes::FakeText.extra_config_field_items = {}
    NibbleFakes::FakeText.instance_variable_set(:@config_fields, nil)
  end

  test "fieldtype config merges declared defaults under the field's own values" do
    field = fields([ { handle: "title", field: { type: "fake_text", character_limit: 90 } } ]).get("title")

    assert_equal({ "character_limit" => 90, "input_type" => "text" }, field.fieldtype.config.slice("character_limit", "input_type"))
    assert_equal "text", field.to_publish_h["config"]["input_type"]
  end

  test "the value pipeline runs through the fieldtype: default, pre_process for editing, process for storage, preload meta" do
    result = fields([
      { handle: "code", field: { type: "fake_upcase" } },
      { handle: "count", field: { type: "fake_integer" } },
      { handle: "note", field: { type: "fake_text", default: "hello" } }
    ]).add_values("code" => "ABC")

    editing = result.pre_process.values
    assert_equal({ "code" => "abc", "count" => 0, "note" => "hello" }, editing)

    stored = result.add_values("code" => "xyz", "count" => "7").process.values
    assert_equal "XYZ", stored["code"]
    assert_equal 7, stored["count"]

    assert_equal({ "hint" => "upcased on save" }, result.meta["code"])
  end

  test "computed defaults resolve through registered resolvers, and unknown ones fail loud" do
    Nibble::Defaults.register("today") { "2026-09-17" }
    field = fields([ { handle: "date", field: { type: "fake_text", default: "computed:today" } } ]).get("date")
    assert_equal "2026-09-17", field.default_value

    missing = fields([ { handle: "date", field: { type: "fake_text", default: "computed:nope" } } ]).get("date")
    assert_raises(Nibble::Error, match: /no computed default 'nope'/) { missing.default_value }
  ensure
    Nibble::Defaults.reset!
  end

  test "visibility, listing and sorting follow the common option rules" do
    result = fields([
      { handle: "legacy", field: { type: "fake_text", read_only: true } },
      { handle: "total", field: { type: "fake_text", visibility: "computed" } },
      { handle: "internal", field: { type: "fake_text", listable: false } },
      { handle: "title", field: { type: "fake_text", listable: true, validate: "required|max:120" } }
    ])

    assert_equal "read_only", result.get("legacy").visibility
    assert_not result.get("total").sortable?, "computed values aren't stored, so they can't be sorted"
    assert_not result.get("internal").listable?
    assert_not result.get("internal").filterable?
    assert result.get("title").visible_on_listing?
    assert result.get("title").required?, "a 'required' rule makes the field required"
    assert_equal %w[required max:120], result.get("title").validation_rules
  end

  test "the publish array carries everything the CP needs, but never validation rules" do
    publish = fields([ { handle: "title", field: { type: "fake_text", display: "Title", width: 50, if: { status: "published" }, validate: [ "required" ] } } ]).to_publish_a.first

    assert_equal "title", publish["handle"]
    assert_equal "fake_text", publish["component"]
    assert_equal 50, publish["width"]
    assert publish["required"]
    assert_equal({ "status" => "published" }, publish["if"])
    assert_not publish.key?("validate")
    assert_not publish["config"].key?("validate")
  end
end
