require "test_helper"

class Nibble::Fieldtypes::ScalarFieldtypesTest < ActiveSupport::TestCase
  def field(type, config = {}, value: nil)
    Nibble::Field.new("subject", { "type" => type }.merge(config.deep_stringify_keys), value:)
  end

  def fieldtype(type, config = {}) = field(type, config).fieldtype

  def errors(type, config, value)
    fields = Nibble::Fields.new([ { handle: "subject", field: { type: }.merge(config) } ], source: "test")
    Nibble::Validator.new(fields).validate("subject" => value).errors["subject"]
  end

  test "the core fieldtypes are registered under their schema handles" do
    %w[text textarea integer toggle select radio checkboxes date slug].each do |handle|
      assert Nibble::Fieldtypes.exists?(handle), "#{handle} should be registered"
    end
  end

  test "text: number inputs store numbers, and email/url/limit are enforced on the server too" do
    assert_equal 42, fieldtype(:text, input_type: "number").process("42")
    assert_in_delta 4.5, fieldtype(:text, input_type: "number").process("4.5")
    assert_equal "42", fieldtype(:text).process("42")

    assert_match "valid email", errors("text", { input_type: "email" }, "nope").first
    assert_match "not be greater than 5 characters", errors("text", { character_limit: 5 }, "too long").first
    assert_nil errors("text", { input_type: "email" }, "")
  end

  test "text listing cells carry prepend/append" do
    assert_equal "$10 AUD", fieldtype(:text, prepend: "$", append: " AUD").pre_process_index("10")
    assert_nil fieldtype(:text, prepend: "$").pre_process_index(nil)
  end

  test "integer: blank submissions store nil, min and max come from config" do
    assert_nil fieldtype(:integer).process("")
    assert_equal 7, fieldtype(:integer).process("7")
    assert_match "at least 1", errors("integer", { min: 1 }, 0).first
    assert_match "must be an integer", errors("integer", {}, "1.5").first
  end

  test "toggle: defaults to off, and stored strings become booleans" do
    assert_equal false, field(:toggle).pre_process.value
    assert_equal false, fieldtype(:toggle).process("0")
    assert_equal true, fieldtype(:toggle).process("1")
    assert_nil fieldtype(:toggle).process(nil), "an unset toggle stays unset"
    assert_equal false, fieldtype(:toggle).augment(nil)
  end

  test "select options accept a list, a key → label map, or key/label items" do
    assert_equal [ { "value" => "a", "label" => "a" } ], fieldtype(:select, options: %w[a]).options
    assert_equal [ { "value" => "sm", "label" => "Small" } ], fieldtype(:select, options: { "sm" => "Small" }).options
    assert_equal [ { "value" => "sm", "label" => "Small" } ], fieldtype(:select, options: [ { "key" => "sm", "label" => "Small" } ]).options
  end

  test "select augments to value + label so themes never re-derive labels" do
    sizes = { options: { "sm" => "Small", "lg" => "Large" } }

    assert_equal({ "value" => "lg", "label" => "Large" }, fieldtype(:select, sizes).augment("lg"))
    assert_equal [ { "value" => "sm", "label" => "Small" } ], fieldtype(:select, sizes.merge(multiple: true)).augment([ "sm" ])
    assert_equal [], fieldtype(:select, sizes.merge(multiple: true)).augment(nil)
    assert_raises(Nibble::Error) { fieldtype(:select, sizes).augment(%w[sm lg]) }
  end

  test "select rejects values that aren't options, unless additions are allowed" do
    assert_match "selected Subject is invalid", errors("select", { options: %w[a b] }, "z").first
    assert_nil errors("select", { options: %w[a b], taggable: true }, "z")
    assert_match "not have more than 1 items", errors("select", { options: %w[a b], multiple: true, max_items: 1 }, %w[a b]).first
  end

  test "cast_booleans round-trips true/false through the string options editors pick" do
    yes_no = fieldtype(:select, options: { "true" => "Yes", "false" => "No" }, cast_booleans: true)

    assert_equal true, yes_no.process("true")
    assert_equal "false", yes_no.pre_process(false)
    assert_equal({ "value" => true, "label" => "Yes" }, yes_no.augment(true))
  end

  test "checkboxes are always multiple and drop blanks" do
    boxes = fieldtype(:checkboxes, options: %w[a b])

    assert_equal [], boxes.pre_process(nil)
    assert_equal %w[a], boxes.process([ "a", nil ])
    assert_nil errors("checkboxes", { options: %w[a b] }, [ "a", "" ])
  end

  test "radio is single-valued" do
    assert_equal "a", fieldtype(:radio, options: %w[a b]).process([ "a" ])
  end

  test "date without time stores a plain ISO date; with time it stores UTC to the minute" do
    assert_equal "2026-09-17", fieldtype(:date).process("2026-09-17T15:30:00Z")
    assert_equal "2026-09-17T15:30:00Z", fieldtype(:date, time_enabled: true).process("2026-09-17T15:30:45Z")
    assert_equal "2026-09-17T15:30:45Z", fieldtype(:date, time_enabled: true, time_seconds_enabled: true).process("2026-09-17T15:30:45Z")
    assert_nil fieldtype(:date).process("")
  end

  test "date limits come from config" do
    assert_match "after or equal to 2026-01-01", errors("date", { earliest_date: "2026-01-01" }, "2025-12-31").first
    assert_match "valid date", errors("date", {}, "not a date").first
  end

  test "slug keeps its generation settings for the CP and adds no text rules" do
    config = fieldtype(:slug).config
    assert_equal({ "generate" => true, "from" => "title", "separator" => "-" }, config.slice("generate", "from", "separator"))
    assert_empty fieldtype(:slug).rules
  end
end
