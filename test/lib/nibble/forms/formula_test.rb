require "test_helper"

# Shared with frontend/nibble/__tests__/formula.test.ts: the visitor's running total must be the value the server stores.
class Nibble::Forms::FormulaTest < ActiveSupport::TestCase
  CASES = JSON.parse(Rails.root.join("test/fixtures/files/nibble_formulas.json").read)

  CASES.each do |example|
    test "shared case: #{example['description']}" do
      if example["error"]
        assert_raises(Nibble::Forms::Formula::Error) { Nibble::Forms::Formula.new(example["formula"]) }
      else
        formula = Nibble::Forms::Formula.new(example["formula"])
        result = formula.evaluate(example["values"].to_h, decimals: example["decimals"])
        example["result"].nil? ? assert_nil(result) : assert_equal(example["result"], result)
        assert_equal example["references"], formula.references if example.key?("references")
      end
    end
  end

  test "a whole result is stored as a whole number, so emails and exports don't show 1250.0" do
    assert_kind_of Integer, Nibble::Forms::Formula.new("1000 * 1.25").evaluate({})
  end
end
