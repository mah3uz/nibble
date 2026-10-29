require "test_helper"

class Nibble::Cp::NibbleApi::RelationshipCreateTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  def as_user(user)
    Nibble::Current.session = Struct.new(:user).new(user)
    yield
  ensure
    Nibble::Current.reset
  end
  def create_via(type, params) = post(cp_nibble_relationships_path(type), params:, as: :json)
  def json = JSON.parse(response.body)

  test "a person who can create entries makes one from the picker and gets its summary back to select" do
    sign_in_as users(:editor)

    assert_difference -> { Nibble::Records::Entry.where(collection: "articles").count }, 1 do
      create_via("entry", target: "articles", title: "Made from a field")
    end

    assert_response :created
    entry = Nibble::Records::Entry.find(json["data"]["id"])
    assert_equal "Made from a field", entry.title
    assert_equal "articles", entry.collection
    assert_equal "draft", entry.status
    assert_equal "Made from a field", json["data"]["title"]
  end

  test "a person who can create terms makes one live and gets it back" do
    sign_in_as users(:editor)

    assert_difference -> { Nibble::Records::Term.where(taxonomy: "tags").count }, 1 do
      create_via("term", target: "tags", title: "Fresh tag")
    end

    assert_response :created
    assert_equal "Fresh tag", json["data"]["title"]
    assert Nibble::Records::Term.find(json["data"]["id"]).live?
  end

  test "creating is refused to someone whose role can't create there" do
    sign_in_as users(:author)

    assert_no_difference -> { Nibble::Records::Term.count } do
      create_via("term", target: "tags", title: "Not allowed")
    end
    assert_response :forbidden
  end

  test "a blank title comes back as an error to show, and nothing is saved" do
    sign_in_as users(:editor)

    assert_no_difference -> { Nibble::Records::Entry.count } do
      create_via("entry", target: "articles", title: "  ")
    end
    assert_response :unprocessable_entity
    assert json["errors"]["title"].present?
  end

  test "an unknown target or type is a 404" do
    sign_in_as users(:editor)

    create_via("entry", target: "nope", title: "x")
    assert_response :not_found
    create_via("gadget", target: "articles", title: "x")
    assert_response :not_found
  end

  test "signed-out visitors can't create" do
    assert_no_difference -> { Nibble::Records::Entry.count } do
      create_via("entry", target: "articles", title: "x")
    end
    assert_not_equal 201, response.status
  end

  test "the field offers creation only where the person can create, and only when create is on" do
    field = ->(config) { Nibble::Field.new("topics", { "type" => "terms", "taxonomies" => [ "tags" ] }.merge(config)).fieldtype }

    as_user(users(:editor)) do
      assert_equal [ "tags" ], field.({}).preload["creatable"].pluck("handle")
      assert_empty field.("create" => false).preload["creatable"]
    end
    as_user(users(:author)) do
      assert_empty field.({}).preload["creatable"]
    end
  end

  def add_taxonomy(handle, fields)
    root = @nibble_themes.join("records", "schema")
    root.join("taxonomies", "#{handle}.yml").write({ "title" => handle.titleize, "blueprints" => [ handle.singularize ] }.to_yaml)
    path = root.join("blueprints", "taxonomies", handle, "#{handle.singularize}.yml")
    FileUtils.mkdir_p(path.dirname)
    path.write({ "title" => handle.singularize.titleize, "tabs" => { "main" => { "sections" => [ { "fields" => [
      { "handle" => "title", "field" => { "type" => "text", "required" => true } }, *fields
    ] } ] } } }.to_yaml)
    Nibble.reset_schema!
  end

  test "a target whose blueprint requires a field the dialog can't draw is never offered, so Create can't dead-end" do
    add_taxonomy("badges", [ { "handle" => "icon", "field" => { "type" => "assets", "required" => true } } ])
    add_taxonomy("levels", [ { "handle" => "rank", "field" => { "type" => "integer", "required" => true } } ])
    field = Nibble::Field.new("labels", { "type" => "terms", "taxonomies" => %w[badges levels] }).fieldtype

    as_user(users(:admin)) do
      creatable = field.preload["creatable"]
      assert_equal [ "levels" ], creatable.pluck("handle")
      assert_equal [ "rank" ], creatable.first["fields"].pluck("handle")
    end
  end

  test "an error for a field the dialog has no input for still comes back, keyed by that field, for the dialog to show" do
    add_taxonomy("badges", [ { "handle" => "icon", "field" => { "type" => "assets", "required" => true } } ])
    sign_in_as users(:admin)

    assert_no_difference -> { Nibble::Records::Term.count } do
      create_via("term", target: "badges", title: "Gold")
    end
    assert_response :unprocessable_entity
    assert json["errors"]["icon"].present?
  end

  test "check refuses a mode the picker doesn't know, and accepts each it does" do
    problems = ->(mode) { Nibble::Field.new("topics", { "type" => "entries", "mode" => mode }).fieldtype.config_problems }

    %w[auto default select typeahead stack].each { |mode| assert_empty problems.(mode) }
    assert_match(/mode "sideways"/, problems.("sideways").first)
    assert_empty Nibble::Field.new("topics", { "type" => "terms" }).fieldtype.config_problems
  end

  test "paging passes an offset to the resolver" do
    sign_in_as users(:editor)
    3.times { |i| create_term("Page #{i}") }
    first = JSON.parse((get(cp_nibble_relationships_path("term"), params: { q: "Page", limit: 1 }, as: :json) && response.body))["data"]
    second = JSON.parse((get(cp_nibble_relationships_path("term"), params: { q: "Page", limit: 1, offset: 1 }, as: :json) && response.body))["data"]

    assert_equal 1, first.size
    assert_equal 1, second.size
    assert_not_equal first.first["id"], second.first["id"]
  end
end
