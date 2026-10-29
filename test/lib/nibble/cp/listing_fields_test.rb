require "test_helper"

class Nibble::Cp::ListingFieldsTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  setup do
    schema = @nibble_themes.join("records", "schema")
    schema.join("collections/events.yml").write({ "title" => "Events", "route" => "/events/{slug}", "blueprints" => [ "event" ] }.to_yaml)
    FileUtils.mkdir_p(schema.join("blueprints/collections/events"))
    schema.join("blueprints/collections/events/event.yml").write({ "title" => "Event", "tabs" => { "main" => { "sections" => [ { "fields" => [
      { "handle" => "title", "field" => { "type" => "text", "required" => true } },
      { "handle" => "seats", "field" => { "type" => "integer", "listable" => true } },
      { "handle" => "starts", "field" => { "type" => "date", "time_enabled" => true, "listable" => true } },
      { "handle" => "code", "field" => { "type" => "text", "listable" => true, "sortable" => false } },
      { "handle" => "body", "field" => { "type" => "markdown", "listable" => true } },
      { "handle" => "mood", "field" => { "type" => "select", "options" => { "calm" => "Calm and quiet", "loud" => "Loud" }, "listable" => true } },
      { "handle" => "tags", "field" => { "type" => "checkboxes", "options" => { "a" => "Alpha", "b" => "Beta" }, "listable" => true } },
      { "handle" => "free", "field" => { "type" => "toggle", "listable" => true } },
      { "handle" => "hidden_mood", "field" => { "type" => "select", "options" => %w[x y], "listable" => true, "filterable" => false } },
      { "handle" => "unlisted", "field" => { "type" => "select", "options" => %w[x y], "listable" => false } },
      { "handle" => "forced", "field" => { "type" => "select", "options" => %w[x y], "listable" => false, "filterable" => true } }
    ] } ] } } }.to_yaml)
    Nibble.reset_schema!
  end

  def listing(params = {}) = Nibble::Cp::Listing.new(Nibble.schema.collection("events"), user: users(:editor), params: ActionController::Parameters.new(params))
  def event(title, data = {}) = create_entry("events", { "title" => title }.merge(data))
  def titles(params) = listing(params).props["rows"].map { |row| row["title"] }
  def column(handle) = listing.props["columns"].find { |c| c["handle"] == handle }

  test "an integer column sorts as a number, so 2 comes before 10" do
    event("Ten", "seats" => 10)
    event("Two", "seats" => 2)
    event("Hundred", "seats" => 100)

    assert_equal %w[Two Ten Hundred], titles(sort: "seats", dir: "asc")
    assert_equal %w[Hundred Ten Two], titles(sort: "seats", dir: "desc")
    assert_equal "seats", listing(sort: "seats").props["sort"]["column"]
  end

  test "date-times sort by the moment, and entries without a value stay last in both directions" do
    event("Late", "starts" => "2026-03-01T09:00:00Z")
    event("Early", "starts" => "2025-12-31T23:59:00Z")
    event("None")

    assert_equal %w[Early Late None], titles(sort: "starts", dir: "asc")
    assert_equal %w[Late Early None], titles(sort: "starts", dir: "desc")
  end

  test "equal values fall back to the collection's default order" do
    first = event("First", "seats" => 5)
    second = event("Second", "seats" => 5)
    second.update_columns(updated_at: 1.day.from_now)
    first.update_columns(updated_at: 1.day.ago)

    assert_equal %w[Second First], titles(sort: "seats", dir: "asc")
  end

  test "only fields that hold one ordered value get a sort control" do
    assert column("seats")["sortable"]
    assert column("mood")["sortable"]
    assert column("free")["sortable"]
    assert_not column("code")["sortable"], "sortable: false takes the control away"
    assert_not column("body")["sortable"], "long formatted text has no useful order"
    assert_not column("tags")["sortable"], "a list of choices has no single order"
  end

  test "asking to sort by an unsortable column is ignored" do
    event("Only")
    assert_not_equal "code", listing(sort: "code").props["sort"]["column"]
  end

  test "a choice filter keeps entries holding any chosen option, including inside a multiple choice" do
    event("Calm one", "mood" => "calm", "tags" => %w[a])
    event("Loud one", "mood" => "loud", "tags" => %w[a b])
    event("Quiet tag", "mood" => "loud", "tags" => %w[b])

    assert_equal [ "Calm one" ], titles(field_mood: [ "calm" ])
    assert_equal [ "Loud one", "Quiet tag" ], titles(field_mood: [ "loud" ]).sort
    assert_equal [ "Calm one", "Loud one" ], titles(field_tags: [ "a" ]).sort
    assert_equal 3, titles(field_mood: %w[calm loud]).size
    assert_equal [ "Loud one" ], titles(field_mood: [ "loud" ], field_tags: [ "a" ])
  end

  test "a toggle filter separates on from off, treating a never-set toggle as off" do
    event("On", "free" => true)
    event("Off", "free" => false)
    event("Never")

    assert_equal [ "On" ], titles(field_free: "1")
    assert_equal %w[Never Off], titles(field_free: "0").sort
  end

  test "a date range includes the whole of its last day" do
    event("Before", "starts" => "2026-02-28T23:00:00Z")
    event("Inside", "starts" => "2026-03-05T20:00:00Z")
    event("Last day", "starts" => "2026-03-10T23:30:00Z")
    event("After", "starts" => "2026-03-11T01:00:00Z")
    event("Unset")

    assert_equal [ "Inside", "Last day" ], titles(field_starts_from: "2026-03-01", field_starts_to: "2026-03-10").sort
    assert_equal [ "After" ], titles(field_starts_from: "2026-03-11")
    assert_equal [ "Before" ], titles(field_starts_to: "2026-02-28")
  end

  test "a filtered listing narrows in SQL and never loads unrelated rows' data" do
    40.times { |i| event("Row #{i}", "mood" => i.zero? ? "calm" : "loud", "free" => i.even?, "starts" => "2026-0#{1 + i % 2}-15T10:00:00Z") }
    sql = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| sql << payload[:sql] }
    result = titles(field_mood: [ "calm" ], field_free: "1", field_starts_from: "2026-01-01", field_starts_to: "2026-01-31")
    ActiveSupport::Notifications.unsubscribe(subscriber)

    assert_equal [ "Row 0" ], result
    loads = sql.select { |query| query.match?(/SELECT "entries"\.\* FROM "entries"/) && query.exclude?("LIMIT") == false }
    assert loads.any? && loads.all? { |query| query.include?("CAST(") }, "only the filtered rows are loaded"
    assert sql.none? { |query| query.match?(/SELECT "entries"\."id", "entries"\."data" FROM/) }, "no query reads every row's whole data"
    assert sql.any? { |query| query.include?("CAST(") && query.include?("'calm'") }, "the choice is filtered by the database"
  end

  test "many rows filter exactly, array choices included" do
    60.times { |i| event("Row #{i}", "mood" => %w[calm loud][i % 2], "tags" => i % 3 == 0 ? %w[a b] : %w[b], "free" => i % 5 == 0) }

    assert_equal 30, listing(field_mood: [ "calm" ], per_page: 100).props["pagination"]["total"]
    assert_equal 20, listing(field_tags: [ "a" ], per_page: 100).props["pagination"]["total"]
    assert_equal 8, listing(field_tags: [ "a" ], field_mood: [ "calm" ], field_free: "0", per_page: 100).props["pagination"]["total"]
  end

  test "filters are offered in plain words, only for filterable fields" do
    filters = listing.props["filters"].to_h { |filter| [ filter["handle"], filter ] }

    assert_equal "multi_select", filters["field_mood"]["type"]
    assert_equal [ "Calm and quiet", "Loud" ], filters["field_mood"]["options"].map { |option| option["label"] }
    assert_equal [ "Alpha", "Beta" ], filters["field_tags"]["options"].map { |option| option["label"] }
    assert_equal %w[Yes No], filters["field_free"]["options"].map { |option| option["label"] }
    assert_equal [ "Starts from", "Starts to" ], [ filters["field_starts_from"], filters["field_starts_to"] ].map { |filter| filter["label"] }
    assert_not filters.key?("field_hidden_mood"), "filterable: false removes the filter"
    assert_not filters.key?("field_unlisted"), "a field that is not listed is not filterable unless it says so"
    assert filters.key?("field_forced")
    assert_not filters.key?("field_code")
  end
end
