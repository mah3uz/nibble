require "test_helper"

class Nibble::SafeUrlTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  UNSAFE = [ "javascript:alert(1)", " JavaScript:alert(1)", "data:text/html,<script>", "vbscript:x" ].freeze

  test "only links a theme can put in an href unharmed are safe" do
    %w[https://example.com http://a.test mailto:a@b.test tel:+15551234 /about #top ?page=2].each { |url| assert Nibble::SafeUrl.safe?(url), url }
    UNSAFE.each { |url| assert_not Nibble::SafeUrl.safe?(url), url }
  end

  test "a navigation menu refuses a link that would run script on every page" do
    menu = ->(url) { Nibble::Records::NavigationTree.new(handle: "main", locale: "en", tree: [ { "type" => "url", "title" => "Click", "url" => url } ]) }

    assert menu.("https://example.com").valid?
    UNSAFE.each { |url| assert_not menu.(url).valid?, url }
  end

  test "a link field refuses a javascript: URL but takes a link to an entry" do
    fields = Nibble::Fields.new([ { "handle" => "cta", "field" => { "type" => "link" } } ])
    errors = ->(value) { Nibble::Validator.new(fields).validate({ "cta" => value }).errors }

    assert errors.("javascript:alert(1)").any?
    assert_empty errors.("entry::5")
    assert_empty errors.("https://example.com")
  end
end
