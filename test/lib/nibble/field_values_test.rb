require "test_helper"

# Two rules keep stored content honest: a field is stored only while it holds a value, and a default is what
# something new starts with, never a stand-in for a value an existing record doesn't have.
class Nibble::FieldValuesTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def fields(definitions) = Nibble::Fields.new(definitions, source: "test")

  test "clearing a field stores nothing, whatever shape its empty value takes" do
    article = create_entry("articles", { "summary" => "Old", "blocks" => [ { "type" => "quote" } ] })
    lifecycle(article, :save, "summary" => "", "blocks" => [], "related" => [])

    assert_empty article.reload.data.keys & %w[summary blocks related]
  end

  test "false and 0 are values, so a switched-off toggle and a zero are kept" do
    stored = fields([ { handle: "on", field: { type: "toggle" } }, { handle: "count", field: { type: "integer" } },
                      { handle: "score", field: { type: "text", input_type: "number" } },
                      { handle: "note", field: { type: "text" } } ])
      .add_values("on" => false, "count" => 0, "score" => "", "note" => "").process.values

    assert_equal({ "on" => false, "count" => 0, "score" => nil, "note" => nil }, stored)
  end

  test "an empty value inside a grid row is stored as nothing too" do
    grid = fields([ { handle: "rows", field: { type: "grid", fields: [ { handle: "label", field: { type: "text" } },
                                                                        { handle: "note", field: { type: "text" } } ] } } ])

    row = grid.add_values("rows" => [ { "_id" => "r1", "label" => "A", "note" => "" } ]).process.values["rows"].sole
    assert_equal({ "id" => "r1", "label" => "A" }, row)
  end

  test "a new row starts from its defaults in the editor" do
    grid = fields([ { handle: "rows", field: { type: "grid", fields: [ { handle: "label", field: { type: "text", default: "Untitled" } } ] } } ])

    assert_equal({ "label" => "Untitled" }, grid.get("rows").fieldtype.preload["defaults"])
  end
end

class Nibble::FieldDefaultsTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  setup { seed_starter_site }

  def save_global(record, values, mode: nil)
    options = mode ? { mode: } : {}
    result = Nibble::Lifecycle.call(record, :save, values, actor: Nibble::Principal.system, **options)
    assert result.ok?, "save failed: #{result.errors}"
    record.reload
  end

  def new_integrations = Nibble::Records::GlobalSet.new(handle: "integrations", locale: "en")

  test "a new record starts from its defaults, whoever creates it" do
    assert_equal 0.5, save_global(new_integrations, { "mail_from_name" => "Tidewater" }).data["recaptcha_min_score"]
  end

  test "a default cleared as the record is created stays cleared" do
    assert_not save_global(new_integrations, { "recaptcha_min_score" => "" }).data.key?("recaptcha_min_score")
  end

  test "an existing record without a value isn't given the default, so the form shows what the site shows" do
    global = save_global(new_integrations, { "recaptcha_min_score" => "" })
    form = global.blueprint_fields.add_values(global.data).pre_process.values

    assert_nil form["recaptcha_min_score"]
    assert_not save_global(global, form).data.key?("recaptcha_min_score"), "saving the untouched form must not write the default"
  end

  test "an import reproduces its source, so a field empty there isn't filled with a default here" do
    global = save_global(new_integrations, { "mail_from_name" => "Tidewater" }, mode: :import)

    assert_not global.data.key?("recaptcha_min_score")
  end
end
