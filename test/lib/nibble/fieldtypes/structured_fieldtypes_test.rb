require "test_helper"

class Nibble::Fieldtypes::StructuredFieldtypesTest < ActiveSupport::TestCase
  class FakeResolver
    attr_reader :calls

    def initialize(records)
      @records = records
      @calls = []
    end

    def find(ids, scope:)
      @calls << { ids:, scope: }
      ids.filter_map do |id|
        record = @records[id.to_s] or next
        next if scope["collections"].present? && !scope["collections"].include?(record["collection"])

        record.merge("id" => id.to_s)
      end
    end
  end

  HERO = { "hero" => { "display" => "Hero", "fields" => [ { "handle" => "title", "field" => { "type" => "text", "required" => true } } ] } }.freeze

  setup do
    @entries = FakeResolver.new(
      "1" => { "title" => "About", "url" => "/about", "collection" => "pages", "status" => "published", "edit_url" => "/admin/entries/1" },
      "2" => { "title" => "Hello", "url" => "/blog/hello", "collection" => "posts", "status" => "draft", "edit_url" => "/admin/entries/2" }
    )
    @assets = FakeResolver.new("a1" => { "title" => "Dog", "url" => "/assets/a1/dog.jpg", "alt" => "A dog", "thumbnail" => "/t.jpg" })
    Nibble::Resolvers.register("entry", @entries)
    Nibble::Resolvers.register("asset", @assets)
  end

  teardown do
    Nibble::Resolvers.unregister("asset")
    Nibble.boot!
  end

  def fieldtype(type, config = {}, value: nil, **options)
    Nibble::Field.new("items", { "type" => type }.merge(config.merge(options).deep_stringify_keys), value:).fieldtype
  end

  def errors(definition, value)
    fields = Nibble::Fields.new([ { handle: "items", field: definition } ], source: "test")
    Nibble::Validator.new(fields).validate("items" => value).errors
  end

  test "grid rows keep a stable id: the CP edits _id, storage keeps id" do
    grid = fieldtype(:grid, fields: [ { handle: "label", field: { type: "text" } } ])

    editing = grid.pre_process([ { "id" => "row1", "label" => "A" } ])
    assert_equal [ { "label" => "A", "_id" => "row1" } ], editing
    assert_equal [ { "id" => "row1", "label" => "A" } ], grid.process(editing)
    assert_equal 8, grid.process([ { "label" => "New" } ]).first["id"].length
  end

  test "grid validates each row's fields and row counts" do
    definition = { type: "grid", max_rows: 1, fields: [ { handle: "label", field: { type: "text", required: true } } ] }

    assert_equal %w[items items.1.label], errors(definition, [ { "label" => "ok" }, { "label" => "" } ]).keys.sort
  end

  test "grid preload gives defaults, new-row meta and meta per existing row" do
    grid = fieldtype(:grid, { fields: [ { handle: "label", field: { type: "text", default: "Untitled" } } ] }, value: [ { "_id" => "r1", "label" => "A" } ])

    assert_equal({ "label" => "Untitled" }, grid.preload["defaults"])
    assert_equal %w[r1], grid.preload["existing"].keys
  end

  test "replicator stores type and id, keeps enabled only when a set is switched off" do
    blocks = fieldtype(:replicator, sets: HERO)

    stored = blocks.process([ { "_id" => "b1", "type" => "hero", "enabled" => true, "title" => "Hi" }, { "_id" => "b2", "type" => "hero", "enabled" => false, "title" => "Off" } ])
    assert_equal [ { "id" => "b1", "type" => "hero", "title" => "Hi" }, { "id" => "b2", "type" => "hero", "enabled" => false, "title" => "Off" } ], stored
    assert_equal [ { "type" => "hero", "title" => "Hi", "_id" => "b1", "enabled" => true } ], blocks.pre_process([ stored.first ])
  end

  test "replicator augments enabled sets only, and validates each set by its own fields" do
    blocks = fieldtype(:replicator, sets: HERO)
    assert_equal [ { "title" => "Hi", "id" => "b1", "type" => "hero" } ],
      blocks.augment([ { "id" => "b1", "type" => "hero", "title" => "Hi" }, { "id" => "b2", "type" => "hero", "enabled" => false, "title" => "x" } ])

    assert_equal %w[items.0.title], errors({ type: "replicator", sets: HERO }, [ { "type" => "hero", "title" => "" } ]).keys
    assert errors({ type: "replicator", sets: HERO, max_sets: 1 }, [ { "type" => "hero", "title" => "a" }, { "type" => "hero", "title" => "b" } ]).key?("items")
  end

  test "entries store ids (one id when max_items is 1) and augment to resolved summaries" do
    related = fieldtype(:entries)
    single = fieldtype(:entries, max_items: 1)

    assert_equal %w[1 2], related.process([ "1", "", "2" ])
    assert_nil related.process([])
    assert_equal "1", single.process([ "1" ])
    assert_equal [ "About", "Hello" ], related.augment(%w[1 2]).map { |item| item["title"] }
    assert_equal "About", single.augment("1")["title"]
    assert_equal [ [ "entry", "1" ] ], single.relations("1")
    assert_equal [ "entry:1" ], single.dependencies("1")
  end

  test "entries reject ids that don't exist or sit outside the allowed collections" do
    assert_empty errors({ type: "entries", collections: [ "pages" ] }, [ "1" ])
    assert errors({ type: "entries", collections: [ "pages" ] }, [ "2" ]).key?("items"), "a post can't be picked where only pages are allowed"
    assert errors({ type: "entries" }, [ "999" ]).key?("items")
    assert_equal({ "collections" => [ "pages" ] }, @entries.calls.first[:scope])
  end

  test "assets keep per-use alt text that overrides the asset's own alt" do
    image = fieldtype(:assets, max_files: 1)

    assert_equal({ "asset" => "a1", "alt" => "Our dog" }, image.process([ { "asset" => "a1", "alt" => "Our dog" } ]))
    assert_equal "Our dog", image.augment({ "asset" => "a1", "alt" => "Our dog" })["alt"]
    assert_equal "A dog", image.augment({ "asset" => "a1" })["alt"]
    assert_nil image.process([ { "asset" => "" } ])
  end

  test "assets can require alt text per use" do
    result = errors({ type: "assets", alt: "required" }, [ { "asset" => "a1", "alt" => "" } ])
    assert_equal %w[items.0.alt], result.keys
  end

  test "nested fields reach the CP already in publish shape, so rows and sets render with the same field chrome" do
    grid = Nibble::Fields.new([ { handle: "items", field: { type: "grid", fields: [ { handle: "label", field: { type: "text", required: true } } ] } } ], source: "test")
    row_field = grid.to_publish_a.first.dig("config", "fields", 0)
    assert_equal [ "label", "text", true ], row_field.values_at("handle", "component", "required")

    blocks = Nibble::Fields.new([ { handle: "items", field: { type: "replicator", sets: HERO } } ], source: "test")
    group = blocks.to_publish_a.first.dig("config", "sets", 0)
    assert_equal "main", group["handle"]
    assert_equal [ "hero", "Hero", "title" ], [ group.dig("sets", 0, "handle"), group.dig("sets", 0, "display"), group.dig("sets", 0, "fields", 0, "handle") ]
  end

  test "relationship fields fail loud when no resolver is registered for their records" do
    Nibble::Resolvers.unregister("term")
    assert_raises(Nibble::Error, match: /no record resolver is registered for 'term'/) { fieldtype(:terms).augment([ "5" ]) }
  end
end
