require "test_helper"

class Nibble::Forms::DefinitionTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  setup { Nibble::Defaults.register("today") { "2026-09-17" } }
  teardown { Nibble::Defaults.reset! }

  def definition(handle) = Nibble::Forms::Definition.call(Nibble::Forms.find(handle))

  def problems(content)
    item = Nibble::Schema::Item.new(kind: :forms, handle: "x", parent: nil, path: "x.yml", layer: :site, data: content.deep_stringify_keys)
    Nibble::Forms.problems(Nibble::Forms::Form.new(item:), schema: Nibble.schema)
  end

  def submit(params) = Nibble::Forms::Submit.call(Nibble::Forms.find("visit"), params, ip: "203.0.113.1", user_agent: "test", locale: "en")

  test "a sectioned form hands the theme every field in order, flat as before, and the sections as lists of handles" do
    visit = definition("visit")

    assert_equal %w[name budget note], visit["fields"].map { |field| field["handle"] }
    assert_equal [
      { "display" => "Your details", "instructions" => "So we can greet you.", "fields" => %w[name budget] },
      { "display" => "The visit", "instructions" => nil, "fields" => %w[note] }
    ], visit["sections"]
  end

  test "a flat form has no sections, so a theme can tell it from a sectioned one" do
    assert_nil definition("contact")["sections"]
  end

  test "prepend and append reach the theme, so it can draw them beside the input" do
    budget = definition("visit")["fields"].find { |field| field["handle"] == "budget" }

    assert_equal [ "$", "per head" ], budget.values_at("prepend", "append")
  end

  test "an integer field's min, max and step reach the theme, so it can draw a number input with them" do
    amount = definition("pledge")["fields"].first

    assert_equal [ 2000, 10_000, 500 ], amount.values_at("min", "max", "step")
  end

  test "settings a fieldtype already takes reach the theme, and a computed default arrives resolved" do
    fields = definition("settings")["fields"].index_by { |field| field["handle"] }

    assert_equal "email", fields["email"]["autocomplete"]
    assert_equal 8, fields["message"]["rows"]
    assert_equal [ "I agree to the terms", true ], fields["agree"].values_at("inline_label", "default")
    assert_equal [ true, "2026-01-01", "2030-12-31" ], fields["arrival"].values_at("time_enabled", "earliest_date", "latest_date")
    assert_equal "2026-09-17", fields["arrival"]["default"], "computed:today is a date, not the literal"
    assert_equal [ 2, true ], fields["topics"].values_at("max_items", "clearable")
  end

  test "a field with no default sends none" do
    assert_not definition("settings")["fields"].find { |field| field["handle"] == "message" }.key?("default")
  end

  test "a public submission off the step, counted from min, is refused and one on it is accepted" do
    pledge = ->(amount) { Nibble::Forms::Submit.call(Nibble::Forms.find("pledge"), { "amount" => amount }, ip: "203.0.113.2", user_agent: "test", locale: "en") }

    refused = pledge.(2250)
    assert_equal :invalid, refused.status
    assert_equal [ "The Amount field must go up in steps of 500 (from 2000)." ], refused.errors["amount"]
    assert_equal :ok, pledge.("2500").status
  end

  test "a blueprint integer field treats step as a hint, so an off-step value still saves" do
    assert_equal 12, create_entry("articles", { seats: 12 }).data["seats"]
  end

  test "a required field inside a section is enforced and a valid submission is stored, as for a flat form" do
    result = submit("note" => "hi")
    assert_equal :invalid, result.status
    assert_equal [ "name" ], result.errors.keys

    result = submit("name" => "Ada", "budget" => "5", "note" => "hi")
    assert_equal :ok, result.status
    assert_equal({ "name" => "Ada", "budget" => 5, "note" => "hi" }, result.submission.data)
  end

  test "captcha is nil unless the form asks for one, empty while the keys are missing, and filled once they are set" do
    assert_nil definition("contact")["captcha"]
    assert_equal({ "provider" => nil, "site_key" => nil }, definition("signup")["captcha"])
    result = Nibble::Forms::Submit.call(Nibble::Forms.find("signup"), { "email" => "a@example.test", "_captcha" => "x" }, ip: "203.0.113.1", user_agent: "test", locale: "en")
    assert_equal :invalid, result.status, "a form with no keys still refuses everyone"

    record = Nibble::Records::GlobalSet.find_or_initialize_by(handle: "integrations", locale: "en")
    values = { "captcha_provider" => "turnstile", "captcha_site_key" => "site-1", "captcha_secret_key" => { "plain" => "s" } }
    assert Nibble::Lifecycle.call(record, :save, values, actor: Nibble::Principal.system).ok?
    assert_equal({ "provider" => "turnstile", "site_key" => "site-1" }, definition("signup")["captcha"])
  end

  test "giving both fields and sections, a section without fields, or neither is a problem" do
    field = { handle: "a", field: { type: "text" } }

    assert_includes problems(title: "X", fields: [ field ], sections: [ { fields: [ field ] } ]), "give `fields` or `sections`, not both"
    assert_includes problems(title: "X", sections: [ { display: "One" } ]), "sections.0 needs a `fields` list"
    assert_includes problems(title: "X"), "needs `fields` or `sections`"
    assert_empty problems(title: "X", sections: [ { display: "One", fields: [ field ] } ])
  end
end
