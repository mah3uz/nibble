require "test_helper"

class Nibble::LifecycleReadOnlyTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  setup { use_read_only_notes }

  def editor = users(:editor)

  def stored_note
    create_entry("notes", { "title" => "Note", "code" => "SYS-1", "origin" => "import", "reference" => "R-1",
      "rows" => [ { "id" => "row1", "label" => "First", "checksum" => "c1" }, { "id" => "row2", "label" => "Second", "checksum" => "c2" } ],
      "blocks" => [ { "id" => "set1", "type" => "item", "name" => "One", "source" => "s1" } ] })
  end

  test "a person's save keeps what a read-only field held, saves the rest, and says what it ignored" do
    entry = stored_note

    result = lifecycle(entry, :save, { "title" => "Renamed", "code" => "HACKED", "origin" => "forged" }, actor: editor)

    assert result.ok?
    entry.reload
    assert_equal [ "Renamed", "SYS-1", "import" ], entry.values.values_at("title", "code", "origin"),
      "read_only: true and visibility: read_only are both kept; the title still changes"
    assert_equal %w[code origin], result.ignored
  end

  test "sending a read-only field's own value back isn't reported as ignored" do
    entry = stored_note

    result = lifecycle(entry, :save, { "title" => "Again", "code" => "SYS-1" }, actor: editor)

    assert_equal [], result.ignored
  end

  test "Nibble itself, as imports and tasks do, can still write a read-only field" do
    entry = stored_note

    result = lifecycle(entry, :save, { "code" => "SYS-2" })

    assert result.ok?
    assert_equal "SYS-2", entry.reload.values["code"]
    assert_equal [], result.ignored
  end

  test "a new record takes a read-only field only from its default" do
    result = lifecycle(Nibble::Records::Entry.new(collection: "notes"), :create, { "title" => "New", "code" => "MINE", "origin" => "forged" }, actor: editor)

    assert result.ok?
    values = result.record.values
    assert_nil values["code"], "a read-only field without a default starts empty"
    assert_equal "web", values["origin"], "a read-only field with a default starts from it"
  end

  test "a read-only field on a live entry is kept in its draft and stays kept when the draft is published" do
    entry = publish_entry(stored_note)

    lifecycle(entry, :save, { "title" => "Draft", "code" => "HACKED" }, actor: editor)
    assert_equal "SYS-1", entry.reload.draft.data["code"]

    result = lifecycle(entry, :publish, { "code" => "HACKED AGAIN" }, actor: editor)
    assert result.ok?
    assert_equal [ "Draft", "SYS-1" ], entry.reload.values.values_at("title", "code")
  end

  test "reverting to an older revision doesn't bring back an older read-only value" do
    entry = stored_note
    old = entry.revisions.order(:number).last
    lifecycle(entry, :save, { "code" => "SYS-2" })

    assert lifecycle(entry.reload, :revert, { "revision_id" => old.id }, actor: editor).ok?
    assert_equal "SYS-2", entry.reload.values["code"]
  end

  test "a conditionally read-only field is kept only while its condition passes on the values sent" do
    entry = stored_note

    lifecycle(entry, :save, { "reference" => "R-2" }, actor: editor)
    assert_equal "R-2", entry.reload.values["reference"], "unlocked, it can be changed"

    lifecycle(entry, :save, { "locked" => true }, actor: editor)
    result = lifecycle(entry.reload, :save, { "reference" => "R-3" }, actor: editor)
    assert_equal "R-2", entry.reload.values["reference"], "locked, it keeps its value"
    assert_equal [ "reference" ], result.ignored

    lifecycle(entry, :save, { "locked" => false, "reference" => "R-4" }, actor: editor)
    assert_equal "R-4", entry.reload.values["reference"], "unlocking in the same save, as the editor sees it, opens it"
  end

  test "rows keep their read-only values by id when they are reordered, and new rows start from the default" do
    entry = stored_note

    result = lifecycle(entry, :save, { "rows" => [
      { "id" => "row2", "label" => "Second, moved up", "checksum" => "forged" },
      { "_id" => "row1", "label" => "First", "checksum" => "c1" },
      { "label" => "Added", "checksum" => "forged too" }
    ] }, actor: editor)

    rows = entry.reload.values["rows"]
    assert_equal [ "Second, moved up", "First", "Added" ], rows.map { |row| row["label"] }
    assert_equal %w[c2 c1 none], rows.map { |row| row["checksum"] }
    assert_equal %w[rows.0.checksum rows.2.checksum], result.ignored
  end

  test "a row given another row's id, or a set given a stored id but another type, is treated as new" do
    entry = stored_note

    lifecycle(entry, :save, { "rows" => [ { "id" => "row1", "label" => "A" }, { "id" => "row1", "label" => "Copy", "checksum" => "c1" } ],
      "blocks" => [ { "id" => "set1", "type" => "item", "name" => "Kept", "source" => "forged" }, { "type" => "item", "name" => "New", "source" => "s9" } ] },
      actor: editor)

    values = entry.reload.values
    assert_equal %w[c1 none], values["rows"].map { |row| row["checksum"] }
    assert_equal [ "s1", nil ], values["blocks"].map { |row| row["source"] }
  end

  test "a row sent without its read-only value keeps it, and a removed row goes with its own" do
    entry = stored_note

    assert lifecycle(entry, :save, { "rows" => [ { "id" => "row2", "label" => "Second" } ] }, actor: editor).ok?
    assert_equal [ "c2" ], entry.reload.values["rows"].map { |row| row["checksum"] }
  end

  test "assigning terms refuses a read-only terms field" do
    path = @nibble_themes.join("records/schema/blueprints/collections/articles/article.yml")
    blueprint = YAML.safe_load(path.read)
    blueprint.dig("tabs", "main", "sections", 0, "fields").find { |field| field["handle"] == "tags" }["field"]["read_only"] = true
    path.write(blueprint.to_yaml)
    Nibble.reset_schema!
    entry = create_entry("articles")
    tag = create_term("Ruby")

    result = lifecycle(entry, :assign_terms, { "field" => "tags", "term_ids" => [ tag.id ] }, actor: editor)

    assert result.invalid?
    assert_equal [ "is read-only" ], result.errors["field"]
  end
end
