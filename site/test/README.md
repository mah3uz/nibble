# Your tests

This directory is yours. Nibble never ships a file here, so nothing you put in it is touched by an upgrade.

`bin/ci` runs it after Nibble's own tests, and `bin/rails test site/test` runs it on its own. Nibble's tests live
in `test/` and are ours — putting yours there means an upgrade can conflict with them.

```ruby
# site/test/models/invoice_test.rb
require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  test "an invoice totals its lines" do
    assert_equal 30, Invoice.new(lines: [ 10, 20 ]).total
  end
end
```

`test_helper` is Nibble's, so fixtures, sign-in helpers and the schema are all set up for you.
