require "test_helper"

class Nibble::LoadHooksTest < ActiveSupport::TestCase
  HOOKS = { nibble_entry: Nibble::Records::Entry, nibble_term: Nibble::Records::Term, nibble_asset: Nibble::Records::Asset }.freeze

  test "a site extends a record through a load hook rather than reopening the class" do
    HOOKS.each do |hook, klass|
      received = nil
      ActiveSupport.on_load(hook) { received = self }

      assert_equal klass, received, "#{hook} must hand the site the class to extend"
    end
  end

  test "what a hook defines is live on the record, so the seam is worth using" do
    ActiveSupport.on_load(:nibble_entry) { def headline = "#{data["title"]}!" }

    entry = Nibble::Records::Entry.new(data: { "title" => "Hello" })
    assert_equal "Hello!", entry.headline
  ensure
    Nibble::Records::Entry.remove_method(:headline) if Nibble::Records::Entry.method_defined?(:headline)
  end
end
