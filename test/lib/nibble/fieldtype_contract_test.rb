require "test_helper"

class Nibble::FieldtypeContractTest < ActiveSupport::TestCase
  include Nibble::Testing::FieldtypeContract

  V1_FIELDTYPES = JSON.parse(Rails.root.join("test/fixtures/files/nibble_fieldtypes.json").read).freeze

  class LossyFieldtype < Nibble::Fieldtype
    self.contract_samples = [ "keep me" ]
    def process(_value) = nil
    def ts_type = "string"
  end

  test "exactly the v1 fieldtypes ship in core" do
    assert_equal V1_FIELDTYPES, Nibble::Fieldtypes::CORE.map { |name| name.constantize.handle }.sort
  end

  Nibble::Fieldtypes::CORE.each do |name|
    klass = name.constantize
    test "#{klass.handle} honours the fieldtype contract" do
      assert_fieldtype_contract(klass)
    end
  end

  test "the contract catches a fieldtype that loses data between editing and saving" do
    Nibble::Fieldtypes.register(LossyFieldtype)
    assert_raises(Minitest::Assertion) { assert_fieldtype_contract(LossyFieldtype) }
  ensure
    Nibble::Fieldtypes.unregister(LossyFieldtype.handle)
  end
end
