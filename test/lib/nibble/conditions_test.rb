require "test_helper"

# Shared with the CP evaluator's tests (vendor/nibble/frontend/nibble-admin/conditions) so server and editor agree on visibility.
class Nibble::ConditionsTest < ActiveSupport::TestCase
  CASES = JSON.parse(Rails.root.join("test/fixtures/files/nibble_conditions.json").read)

  teardown { Nibble::Conditions.reset! }

  CASES.each do |example|
    test "shared case: #{example['description']}" do
      visible = Nibble::Conditions.visible?(example["config"], values: example["values"], root_values: example["root_values"],
        path: example["path"], prefix: example["prefix"])
      assert_equal example["visible"], visible
    end
  end

  test "custom conditions receive params and target, and unregistered ones fail loud" do
    Nibble::Conditions.register("longer_than") { |params:, target:, **| target.to_s.length > params.first.to_i }

    assert Nibble::Conditions.visible?({ "if" => { "title" => "custom longer_than:3" } }, values: { "title" => "Hello" })
    assert_not Nibble::Conditions.visible?({ "if" => { "title" => "custom longer_than:10" } }, values: { "title" => "Hello" })

    Nibble::Conditions.register("never") { |**| false }
    assert Nibble::Conditions.visible?({ "unless" => "custom never" }, values: {}), "a target-less custom condition is inverted by unless"

    assert_raises(Nibble::Error, match: /'missing' isn't registered/) { Nibble::Conditions.visible?({ "if" => "custom missing" }, values: {}) }
  end
end
