require "test_helper"

class Nibble::Cp::EntryDuplicateTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup do
    sign_in_as users(:editor)
    schema = @nibble_themes.join("records", "schema")
    schema.join("collections/recipes.yml").write({ "title" => "Recipes", "route" => "/recipes/{slug}", "blueprints" => [ "recipe" ] }.to_yaml)
    FileUtils.mkdir_p(schema.join("blueprints/collections/recipes"))
    schema.join("blueprints/collections/recipes/recipe.yml").write({ "title" => "Recipe", "tabs" => { "main" => { "sections" => [ { "fields" => [
      { "handle" => "title", "field" => { "type" => "text", "required" => true } },
      { "handle" => "summary", "field" => { "type" => "text" } },
      { "handle" => "sku", "field" => { "type" => "text", "duplicate" => false, "default" => "NEW" } },
      { "handle" => "origin", "field" => { "type" => "text", "visibility" => "read_only", "default" => "web" } },
      { "handle" => "steps", "field" => { "type" => "grid", "fields" => [
        { "handle" => "text", "field" => { "type" => "text" } },
        { "handle" => "timer", "field" => { "type" => "text", "duplicate" => false, "default" => "none" } }
      ] } },
      { "handle" => "related", "field" => { "type" => "entries", "collections" => [ "recipes" ] } }
    ] } ] } } }.to_yaml)
    Nibble.reset_schema!
  end

  def path(entry) = "/cp/collections/recipes/entries/#{entry.id}/duplicate"
  def copy = Nibble::Records::Entry.where(collection: "recipes").order(:id).last
  def page_props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

  def recipe
    other = create_entry("recipes", { "title" => "Other" })
    create_entry("recipes", { "title" => "Soup", "summary" => "Warm", "sku" => "SOUP-1",
                              "related" => [ other.id.to_s ],
                              "steps" => [ { "text" => "Boil", "timer" => "5m" }, { "text" => "Serve", "timer" => "1m" } ] })
  end

  test "a copy is a new draft with the values, a (copy) title and its own slug, and the person lands on it" do
    entry = recipe
    publish_entry(entry)

    assert_difference -> { Nibble::Records::Entry.where(collection: "recipes").count }, 1 do
      post path(entry)
    end

    assert_redirected_to "/cp/collections/recipes/entries/#{copy.id}/edit"
    assert_equal [ "Soup (copy)", "Warm", entry.values["related"] ], copy.values.values_at("title", "summary", "related")
    assert_equal "draft", copy.status
    assert_equal "soup-copy", copy.slug
    assert_nil copy.published_at
  end

  test "a duplicate: false field and a read-only field start from their defaults" do
    entry = recipe

    post path(entry)

    assert_equal "NEW", copy.values["sku"], "a serial number must not be shared"
    assert_equal "web", copy.values["origin"], "a value nobody may edit is not carried over"
  end

  test "rows in a grid get new ids and their duplicate: false fields start from defaults" do
    entry = recipe
    post path(entry)

    assert_equal %w[Boil Serve], copy.values["steps"].map { |row| row["text"] }
    assert_equal %w[none none], copy.values["steps"].map { |row| row["timer"] }
    old_ids = entry.values["steps"].map { |row| row["id"] }
    assert old_ids.all?(&:present?)
    assert_empty old_ids & copy.values["steps"].map { |row| row["id"] }, "a row id follows one row; two entries sharing it would confuse history"
  end

  test "copying again keeps every slug unique" do
    entry = recipe
    3.times { post path(entry) }

    slugs = Nibble::Records::Entry.where(collection: "recipes", title: "Soup (copy)").pluck(:slug)
    assert_equal %w[soup-copy soup-copy-2 soup-copy-3], slugs.sort
  end

  test "the listing menu duplicates one entry" do
    entry = recipe
    get "/cp/collections/recipes"
    assert page_props["listing"]["rows"].any? { |row| row["actions"].include?("duplicate") }

    post "/cp/actions", params: { resource: "collections.recipes", handle: "duplicate", ids: [ entry.id ] }
    assert_redirected_to "/cp/collections/recipes/entries/#{copy.id}/edit"
    assert_equal "Soup (copy)", copy.title
  end

  test "a person who can't create gets no copy and no button" do
    entry = recipe
    reader = Nibble::Role.create!(handle: "reader", title: "Reader", abilities: %w[entries.recipes.view])
    sign_in_as users(:author).tap { |user| user.roles = [ reader ] }

    get "/cp/collections/recipes/entries/#{entry.id}/edit"
    assert_nil page_props.dig("urls", "duplicate")
    get "/cp/collections/recipes"
    assert page_props["listing"]["rows"].none? { |row| row["actions"].include?("duplicate") }

    assert_no_difference -> { Nibble::Records::Entry.count } do
      post path(entry)
      assert_response :forbidden
      post "/cp/actions", params: { resource: "collections.recipes", handle: "duplicate", ids: [ entry.id ] }
      assert_response :forbidden
    end
  end

  test "a collection kept as files offers no Duplicate" do
    entry = recipe
    schema_file = @nibble_themes.join("records/schema/collections/recipes.yml")
    schema_file.write(YAML.safe_load(schema_file.read).merge("files" => "recipes").to_yaml)
    Nibble.reset_schema!

    assert_no_difference -> { Nibble::Records::Entry.count } do
      post path(entry)
    end
    assert_response :not_found
  end

  test "a slug field and a unique field default to not being copied, and an explicit setting wins" do
    field = ->(config) { Nibble::Field.new("f", config.merge("type" => "text")) }
    assert field.call({}).duplicate?
    assert_not field.call("validate" => "required|unique:entries").duplicate?
    assert_not Nibble::Field.new("s", { "type" => "slug" }).duplicate?
    assert Nibble::Field.new("s", { "type" => "slug", "duplicate" => true }).duplicate?
    assert field.call("validate" => [ "unique" ], "duplicate" => true).duplicate?
  end
end
