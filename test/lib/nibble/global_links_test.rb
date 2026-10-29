require "test_helper"

class Nibble::GlobalLinksTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  setup { @site = use_site_addresses(name: "Tidewater", apply_url: "https://example.com/apply", booking: "https://cal.example/book") }

  def link(text, attrs) = { "type" => "text", "text" => text, "marks" => [ { "type" => "link", "attrs" => attrs } ] }
  def render(*content) = RichText::Renderer.call({ "type" => "doc", "content" => [ { "type" => "paragraph", "content" => content } ] })

  test "a link to a global field shows its current address, and follows a change without the page being saved again" do
    stored = link("Apply", "href" => "https://example.com/old-apply", "ref" => "global:site.apply_url")
    assert_equal %(<p><a href="https://example.com/apply">Apply</a></p>), render(stored)

    @site.update!(data: @site.data.merge("apply_url" => "https://example.com/apply-now"))
    assert_equal %(<p><a href="https://example.com/apply-now">Apply</a></p>), render(stored)
  end

  test "a link field in a global works too" do
    assert_equal %(<p><a href="https://cal.example/book">Book</a></p>), render(link("Book", "href" => "", "ref" => "global:site.booking"))
  end

  test "the page is tagged with the global, so changing it clears every page that links to it" do
    _, tags = Nibble::Dependencies.track { render(link("Apply", "href" => "/", "ref" => "global:site.apply_url")) }

    assert_includes tags, "global:site"
  end

  test "a global holding a script link renders the words without a link, never the old address" do
    @site.update!(data: @site.data.merge("apply_url" => "javascript:alert(1)"))
    html = render(link("Apply", "href" => "https://example.com/apply", "ref" => "global:site.apply_url"))

    assert_equal "<p>Apply</p>", html
  end

  test "a global field that is empty renders the words without an empty link" do
    @site.update!(data: @site.data.except("apply_url"))

    assert_equal "<p>Apply</p>", render(link("Apply", "href" => "https://example.com/apply", "ref" => "global:site.apply_url"))
  end

  test "a field that no longer exists falls back to the address stored at save, and only when it is safe" do
    assert_equal %(<p><a href="https://example.com/apply">Apply</a></p>), render(link("Apply", "href" => "https://example.com/apply", "ref" => "global:site.gone"))
    assert_equal "<p>Apply</p>", render(link("Apply", "href" => "javascript:alert(1)", "ref" => "global:nope.apply_url"))
  end

  test "an ordinary link renders as it always has, with or without the editor's empty ref" do
    assert_equal %(<p><a href="https://example.com">Home</a></p>), render(link("Home", "href" => "https://example.com"))
    assert_equal %(<p><a href="https://example.com">Home</a></p>), render(link("Home", "href" => "https://example.com", "ref" => nil))
    assert_equal "<p><a>Home</a></p>", render(link("Home", {}))
  end

  test "only a global field that holds an address can be linked to" do
    assert Nibble::GlobalLinks.field("global:site.apply_url")
    assert_nil Nibble::GlobalLinks.field("global:site.name"), "a plain text field isn't an address"
    assert_nil Nibble::GlobalLinks.field("global:integrations.captcha_secret_key")
    assert_nil Nibble::GlobalLinks.field("global:site.apply_url extra")
  end

  test "saving keeps the stored address at the global's value, so an export still carries a working link" do
    entry = create_entry("articles", { "blocks" => [ { "type" => "rich_text", "text" => [ { "type" => "paragraph", "content" => [
      link("Apply", "href" => "https://example.com/old", "ref" => "global:site.apply_url")
    ] } ] } ] })

    mark = entry.reload.data.dig("blocks", 0, "text", 0, "content", 0, "marks", 0)
    assert_equal({ "href" => "https://example.com/apply", "ref" => "global:site.apply_url" }, mark["attrs"])
  end

  test "a link to a global field that doesn't exist is refused with the reference named" do
    result = lifecycle(Nibble::Records::Entry.new(collection: "articles"), :create, "title" => "Article", "blocks" => [
      { "type" => "rich_text", "text" => [ { "type" => "paragraph", "content" => [ link("Apply", "href" => "/", "ref" => "global:site.gone") ] } ] }
    ])

    refute result.ok?
    assert_match "global:site.gone", result.errors.values.flatten.join
  end

  test "a package carries the reference out and back in, with the address the importing site holds" do
    create_entry("articles", { "title" => "Apply", "blocks" => [ { "type" => "rich_text", "text" => [ { "type" => "paragraph", "content" => [
      link("Apply", "href" => "/", "ref" => "global:site.apply_url")
    ] } ] } ] })
    dir = Pathname(Dir.mktmpdir("nibble-export"))
    Nibble::Packages::Exporter.new(dir).call
    exported = YAML.safe_load_file(dir.join("collections/articles/en/apply.yml"), permitted_classes: [ Date, Time ])
    assert_equal "global:site.apply_url", exported.dig("blocks", 0, "text", 0, "content", 0, "marks", 0, "attrs", "ref")

    Nibble::Records::Entry.delete_all
    @site.update!(data: @site.data.merge("apply_url" => "https://elsewhere.example/apply"))
    report = Nibble::Packages::Importer.new(dir).call
    assert report.ok?, report.errors.join("\n")

    attrs = Nibble::Records::Entry.find_by!(slug: "apply").values.dig("blocks", 0, "text", 0, "content", 0, "marks", 0, "attrs")
    assert_equal({ "href" => "https://elsewhere.example/apply", "ref" => "global:site.apply_url" }, attrs)
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  test "importing content that links to a missing global field reports it before anything is written" do
    dir = Pathname(Dir.mktmpdir("nibble-package"))
    path = dir.join("collections/articles/en/broken.yml")
    path.dirname.mkpath
    path.write({ "title" => "Broken", "status" => "draft", "blocks" => [ { "type" => "rich_text", "text" => [ { "type" => "paragraph", "content" => [
      link("Apply", "href" => "/", "ref" => "global:site.gone")
    ] } ] } ] }.to_yaml)

    report = Nibble::Packages::Importer.new(dir).call

    assert_match "global:site.gone", report.errors.join("\n")
    assert_nil Nibble::Records::Entry.find_by(slug: "broken")
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  test "Markdown writes a global link by its reference and reads it back the same" do
    nodes = Nibble::RichTextMarkdown.to_nodes("[Apply](global:site.apply_url) today")

    assert_equal({ "href" => "https://example.com/apply", "ref" => "global:site.apply_url" }, nodes.dig(0, "content", 0, "marks", 0, "attrs"))
    assert_equal "[Apply](global:site.apply_url) today", Nibble::RichTextMarkdown.to_markdown(nodes)
  end
end
