require "test_helper"

class Nibble::Fieldtypes::ButtonGroupFieldtypeTest < ActiveSupport::TestCase
  OPTIONS = { "options" => { "0" => "Collect", "15" => "Deliver" } }.freeze

  def field(type, config = OPTIONS) = Nibble::Field.new("delivery", { "type" => type }.merge(config))

  def errors(type, value)
    fields = Nibble::Fields.new([ { handle: "delivery", field: { type: }.merge(OPTIONS) } ], source: "test")
    Nibble::Validator.new(fields).validate("delivery" => value).errors["delivery"]
  end

  # Switching a field between radio and button_group must never change what is stored or what a page receives.
  test "a button group stores, validates and reaches a page exactly as a radio with the same options does" do
    inputs = [ "15", [ "0" ], nil ]
    assert_equal inputs.map { |input| field("radio").fieldtype.process(input) }, inputs.map { |input| field("button_group").fieldtype.process(input) }
    assert_equal field("radio").fieldtype.augment("15"), field("button_group").fieldtype.augment("15")
    assert_equal errors("radio", "99"), errors("button_group", "99")
    assert_nil errors("button_group", "15")

    booleans = { "options" => %w[true false], "cast_booleans" => true }
    assert_equal field("radio", booleans).fieldtype.process("true"), field("button_group", booleans).fieldtype.process("true")
  end

  test "a public form hands the theme its options, and a calculation may count a numeric one" do
    definition = Nibble::Forms::Definition.field_definition(field("button_group"))

    assert_equal [ { "value" => "0", "label" => "Collect" }, { "value" => "15", "label" => "Deliver" } ], definition["options"]
    assert Nibble::Forms::Calculations.numeric?(field("button_group"))
    assert_not Nibble::Forms::Calculations.numeric?(field("button_group", "options" => %w[small large]))
  end

  test "an app is told the values it may write" do
    assert_equal %w[0 15], Nibble::Operations::FieldSchema.for(field("button_group"))["enum"]
  end
end
