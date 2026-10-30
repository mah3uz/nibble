require "test_helper"
require_relative "../../test_helpers/nibble_schema_helper"

class Nibble::SetAdjustmentsTest < ActiveSupport::TestCase
  include NibbleSchemaHelper
  include NibbleRecordsHelper

  STANDARD = {
    "content" => { "display" => "Content", "sets" => {
      "text" => { "fields" => [ { "handle" => "body", "field" => { "type" => "textarea" } } ] },
      "embed" => { "fields" => [ { "handle" => "code", "field" => { "type" => "textarea" } } ] }
    } },
    "media" => { "display" => "Media", "sets" => { "image" => { "fields" => [ { "handle" => "alt", "field" => { "type" => "text" } } ] } } }
  }.freeze

  LATEST_POSTS = { "display" => "Latest posts", "fields" => [ { "handle" => "count", "field" => { "type" => "integer", "min" => 1, "max" => 12 } } ] }.freeze

  def schema
    Nibble::Schema.new([ schema_item("fieldsets", "std", title: "Standard", fields: [
      { handle: "blocks", field: { type: "replicator", sets: STANDARD } }
    ]) ])
  end

  def blocks(config = {})
    Nibble::Fields.new([ { handle: "blocks", field: "std.blocks", config: } ], schema:, source: "test", key: "fields").get("blocks")
  end

  def refusal(config)
    assert_raises(Nibble::SchemaError) { blocks(config) }.message
  end

  def set_consts(field) = Nibble::Operations::FieldSchema.for(field).dig("items", "oneOf").map { |set| set.dig("properties", "type", "const") }

  def group_sets(field) = field.to_publish_h.dig("config", "sets").to_h { |group| [ group["handle"], group["sets"].pluck("handle") ] }

  test "an added set joins the end of its group, so the standard blocks keep their order in the menu" do
    field = blocks(add_sets: { content: { latest_posts: LATEST_POSTS } })

    assert_equal({ "content" => %w[text embed latest_posts], "media" => %w[image] }, group_sets(field))
  end

  test "an added group comes after the standard ones" do
    field = blocks(add_sets: { showcase: { display: "Showcase", sets: { latest_posts: LATEST_POSTS } } })

    assert_equal %w[content media showcase], group_sets(field).keys
    assert_equal "Showcase", field.to_publish_h.dig("config", "sets").last["display"]
  end

  test "the validator checks an added set's fields, so a theme's block can't store a bad count" do
    field = blocks(add_sets: { content: { latest_posts: LATEST_POSTS } })
    fields = Nibble::Fields.new([ { handle: "blocks", field: field.config } ], source: "test")
    validate = ->(count) { Nibble::Validator.new(fields).validate("blocks" => [ { "type" => "latest_posts", "count" => count } ]).errors }

    assert_empty validate.(3)
    assert_equal %w[blocks.0.count], validate.(40).keys
  end

  test "the management API offers an added set to connected apps" do
    assert_includes set_consts(blocks(add_sets: { content: { latest_posts: LATEST_POSTS } })), "latest_posts"
  end

  test "an added set's fields are built for the editor, with defaults for a new block" do
    preload = blocks(add_sets: { content: { latest_posts: LATEST_POSTS } }).fieldtype.preload

    assert_includes preload["new"].keys, "latest_posts"
  end

  test "a removed set is gone from the menu, the management API and the set list the check reads" do
    field = blocks(remove_sets: %w[embed image])

    assert_equal({ "content" => %w[text] }, group_sets(field), "a group left empty disappears")
    assert_equal %w[text], field.fieldtype.sets_config.keys
    assert_equal %w[text], set_consts(field)
  end

  test "config still merges shallowly for every other key" do
    field = blocks(button_label: "More", add_sets: { content: { latest_posts: LATEST_POSTS } })

    assert_equal "More", field.get("button_label")
    assert_not field.config.key?("add_sets")
  end

  test "adding a handle that exists is refused, and the message says how to replace it" do
    message = refusal(add_sets: { media: { embed: LATEST_POSTS } })

    assert_includes message, "set 'embed' already exists"
    assert_includes message, "config: sets"
  end

  test "removing a set that isn't there is refused" do
    assert_includes refusal(remove_sets: %w[nonsuch]), "set 'nonsuch' isn't in the field"
  end

  test "a field without sets can't take add_sets" do
    sch = Nibble::Schema.new([ schema_item("fieldsets", "std", title: "Standard", fields: [ { handle: "title", field: { type: "text" } } ]) ])

    assert_raises(Nibble::SchemaError) do
      Nibble::Fields.new([ { handle: "x", field: "std.title", config: { remove_sets: %w[a] } } ], schema: sch, source: "test", key: "fields")
    end
  end

  test "a theme's added set reaches the check, which warns that it has no view" do
    themes = Pathname(Dir.mktmpdir("nibble-themes"))
    write = lambda do |relative, content|
      path = themes.join("check", "schema", relative)
      FileUtils.mkdir_p(path.dirname)
      path.write(content.deep_stringify_keys.to_yaml)
    end
    write.("collections/events.yml", title: "Events", blueprints: [ "event" ])
    write.("blueprints/collections/events/event.yml", title: "Event", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text" } },
      { handle: "blocks", field: "nibble::page_fields.blocks", config: { add_sets: { content: { latest_posts: LATEST_POSTS } } } }
    ] } ] } })
    themes.join("check", "theme.yml").write("name: Check\n")
    config = Nibble::Config.new({ "theme" => "check", "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: themes)

    result = Nibble::Check.run(config:)
    assert(result.warnings.any? { |warning| warning.message.include?("set 'latest_posts' has no view sets/latest_posts.vue") })
  ensure
    FileUtils.rm_rf(themes)
  end

  test "nibble:check refuses to remove a set that saved blocks still use, and names the block count" do
    write_blueprint_with(remove_sets: %w[quote])
    entry = create_entry("articles", { "title" => "A" })
    entry.update_columns(data: entry.data.merge("blocks" => [ { "id" => "aaaaaaaa", "type" => "quote" }, { "id" => "bbbbbbbb", "type" => "rich_text" } ]))

    issues = Nibble::Drift.issues.map { |issue| "#{issue.source}: #{issue.message}" }
    assert_equal [ "collections/articles: set 'quote' of blocks was removed and 1 block still hold it; keep the set, or run nibble:check --allow-data-loss" ], issues
  end

  test "a removed set no saved block uses is not an issue" do
    write_blueprint_with(remove_sets: %w[quote])
    entry = create_entry("articles", { "title" => "A" })
    entry.update_columns(data: entry.data.merge("blocks" => [ { "id" => "bbbbbbbb", "type" => "rich_text" } ]))

    assert_empty Nibble::Drift.issues
  end

  def write_blueprint_with(config)
    @nibble_themes.join("records/schema/fieldsets").tap(&:mkpath).join("kit.yml").write({
      "title" => "Kit", "fields" => [ { "handle" => "blocks", "field" => { "type" => "replicator", "sets" => {
        "quote" => { "fields" => [ { "handle" => "source", "field" => { "type" => "text" } } ] },
        "rich_text" => { "fields" => [ { "handle" => "text", "field" => { "type" => "rich_text" } } ] }
      } } } ]
    }.to_yaml)
    path = @nibble_themes.join("records/schema/blueprints/collections/articles/article.yml")
    blueprint = YAML.safe_load(path.read)
    blueprint["tabs"]["main"]["sections"][0]["fields"].reject! { |item| item["handle"] == "blocks" }
    blueprint["tabs"]["main"]["sections"][0]["fields"] << { "handle" => "blocks", "field" => "kit.blocks", "config" => config.deep_stringify_keys }
    path.write(blueprint.to_yaml)
    Nibble.reset_schema!
  end
end
