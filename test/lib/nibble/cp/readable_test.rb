require "test_helper"

class Nibble::Cp::ReadableTest < ActiveSupport::TestCase
  test "rich text reads as its plain text, not its document JSON" do
    doc = { "type" => "doc", "content" => [ { "type" => "paragraph", "content" => [ { "type" => "text", "text" => "Hello" } ] } ] }

    assert_equal "Hello", Nibble::Cp::Readable.value(doc)
  end

  test "blocks read as a count and their names" do
    rows = [ { "type" => "hero_banner" }, { "type" => "text" } ]

    assert_equal "2 blocks: Hero banner, Text", Nibble::Cp::Readable.value(rows)
  end

  test "toggles and dates read as people say them" do
    assert_equal "On", Nibble::Cp::Readable.value(true)
    assert_equal "Off", Nibble::Cp::Readable.value(false)
    assert_equal "29 Oct 2026", Nibble::Cp::Readable.value("2026-10-29")
    assert_equal "", Nibble::Cp::Readable.value(nil)
  end
end
