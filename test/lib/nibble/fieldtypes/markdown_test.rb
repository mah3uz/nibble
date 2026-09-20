require "test_helper"

class Nibble::Fieldtypes::MarkdownTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  def field(config = {}) = Nibble::Field.new("body", { "type" => "markdown" }.merge(config))

  test "a theme receives HTML, so it renders Markdown without knowing it was Markdown" do
    html = field.fieldtype.augment("## Hi\n\nSome **bold**.\n")

    assert_includes html, "<h2"
    assert_includes html, "<strong>bold</strong>"
    assert_nil field.fieldtype.augment("")
  end

  test "the sanitize switch changes what a theme is given, which is the whole point of it" do
    doc = "# Title\n\n~~gone~~\n"

    assert_includes field.fieldtype.augment(doc), "<h1", "off by default: the author is trusted"
    assert_includes field("sanitize" => true).fieldtype.augment(doc), "<h1", "Markdown's allowlist keeps h1"
    assert_includes field("sanitize" => true).fieldtype.augment(doc), "<del>gone</del>"
  end

  test "an asset is stored as a reference, so replacing it does not leave documents pointing at the old file" do
    asset = create_asset({ "alt" => "A photo" })
    html = field.fieldtype.augment("![A photo](nibble://asset/#{asset.id})\n")

    assert_includes html, asset.url, "the reference resolves to wherever the asset is now"
    assert_not_includes html, "nibble://"
  end

  test "an asset reference is what a content package carries, not a URL from another site" do
    asset = create_asset({ "alt" => "A photo" })
    text = "![A photo](nibble://asset/#{asset.id})"

    assert_equal [ [ "asset", asset.id.to_s ] ], field.fieldtype.relations(text)
    assert_equal [ "asset:#{asset.id}" ], field.fieldtype.dependencies(text)
  end

  test "the listing column shows words, not syntax" do
    assert_equal "Title Some bold text", field.fieldtype.pre_process_index("# Title\n\nSome **bold** text\n")
  end
end
