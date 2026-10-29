require "test_helper"

class Nibble::Fieldtypes::MeasureFieldtypesTest < ActiveSupport::TestCase
  def fieldtype(type, config = {}) = Nibble::Field.new("subject", { "type" => type }.merge(config.deep_stringify_keys)).fieldtype

  def errors(type, config, value)
    fields = Nibble::Fields.new([ { handle: "subject", field: { type: }.merge(config) } ], source: "test")
    Nibble::Validator.new(fields).validate("subject" => value).errors["subject"]
  end

  test "decimal: a value is stored as a number rounded half away from zero to its decimals, so money never carries stray digits" do
    assert_equal 2.68, fieldtype(:decimal).process("2.675")
    assert_equal(-2.68, fieldtype(:decimal).process("-2.675"))
    assert_equal 12.35, fieldtype(:decimal).process(12.345)
    assert_equal 3, fieldtype(:decimal, decimals: 0).process("2.5")
    assert_equal 0.1235, fieldtype(:decimal, decimals: 4).process("0.12345")
    assert_instance_of Float, fieldtype(:decimal).process("5")
    assert_nil fieldtype(:decimal).process("")
  end

  test "decimal: min and max are refused, and text is not a number" do
    assert_match "at least 1", errors("decimal", { min: "1" }, "0.5").first
    assert_match "not be greater than 9.5", errors("decimal", { max: "9.5" }, "9.51").first
    assert_nil errors("decimal", { min: "1", max: "9.5" }, "9.5")
    assert_match "must be a number", errors("decimal", {}, "abc").first
  end

  test "decimal: displays exactly its decimals and describes itself as a multiple of its scale" do
    assert_equal "5.00", fieldtype(:decimal).display(5)
    assert_equal "5", fieldtype(:decimal, decimals: 0).display(5.0)
    assert_equal({ "type" => "number", "minimum" => 1.0, "multipleOf" => 0.01 }, fieldtype(:decimal, min: "1").json_schema)
  end

  test "range: stores a whole number when its bounds and step are whole, else a float" do
    assert_equal 40, fieldtype(:range).process("40")
    assert_instance_of Integer, fieldtype(:range).process(40.0)
    assert_equal 0.5, fieldtype(:range, min: 0, max: 1, step: 0.25).process("0.5")
    assert_nil fieldtype(:range).process("")
  end

  test "range: a value outside min and max is refused" do
    assert_match "not be greater than 100", errors("range", {}, "101").first
    assert_match "at least 10", errors("range", { min: 10 }, "9").first
    assert_nil errors("range", {}, "100")
  end

  test "rating: stores an integer from 1 to max, and nothing when not rated" do
    assert_equal 3, fieldtype(:rating).process("3")
    assert_nil fieldtype(:rating).process("")
    assert_match "not be greater than 5", errors("rating", {}, "6").first
    assert_match "not be greater than 3", errors("rating", { max: 3 }, "4").first
    assert_match "at least 1", errors("rating", {}, "0").first
    assert_match "must be an integer", errors("rating", {}, "2.5").first
    assert_nil errors("rating", { max: 10 }, "10")
  end
end
