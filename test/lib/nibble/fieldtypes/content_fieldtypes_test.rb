require "test_helper"

class Nibble::Fieldtypes::ContentFieldtypesTest < ActiveSupport::TestCase
  QUOTE_SET = { "quote" => { "display" => "Quote", "fields" => [
    { "handle" => "quote", "field" => { "type" => "textarea", "required" => true } },
    { "handle" => "attribution", "field" => { "type" => "text" } }
  ] } }.freeze

  teardown { Nibble.boot! }

  def field(type, config = {}, value: nil)
    Nibble::Field.new("body", { "type" => type }.merge(config.deep_stringify_keys), value:)
  end

  def fieldtype(type, config = {}, value: nil, **options) = field(type, config.merge(options), value:).fieldtype

  def paragraph(text) = { "type" => "paragraph", "content" => [ { "type" => "text", "text" => text } ] }

  def set_node(values, id: "abc12345", enabled: nil)
    attrs = { "id" => id, "values" => values }
    attrs["enabled"] = enabled unless enabled.nil?
    { "type" => "set", "attrs" => attrs }
  end

  class Keys
    MAP = { "7" => "site/hero.jpg", "8" => "site/desk.jpg" }.freeze

    def initialize(direction) = @direction = direction
    def resolve(_type, value) = @direction == :export ? MAP[value.to_s] : MAP.key(value.to_s)
  end

  test "asset references travel as paths, keep their alt text, and come back as the same ids" do
    assets = fieldtype("assets")
    stored = [ { "asset" => "7", "alt" => "Hero" }, { "asset" => "8" } ]

    exported = assets.export(stored, Keys.new(:export))

    assert_equal [ { "asset" => "site/hero.jpg", "alt" => "Hero" }, "site/desk.jpg" ], exported
    assert_equal stored, assets.import(exported, Keys.new(:import))
    assert_equal({ "asset" => "7" }, fieldtype("assets", max_files: 1).import("site/hero.jpg", Keys.new(:import)))
  end

  test "images inside rich text travel as asset paths wherever they are nested" do
    rich = fieldtype("rich_text")
    nested = { "type" => "blockquote", "content" => [ { "type" => "image", "attrs" => { "asset" => "7", "alt" => "Hero" } } ] }
    body = [ paragraph("Before"), nested ]

    exported = rich.export(body, Keys.new(:export))

    assert_equal "site/hero.jpg", exported.last["content"].first.dig("attrs", "asset")
    assert_equal body, rich.import(exported, Keys.new(:import))
  end

  test "the editor gets each image's current URL from its asset, whatever src was stored" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "photo.jpg")
    asset = Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:), :create, {}).record
    body = [
      { "type" => "image", "attrs" => { "asset" => asset.id.to_s, "alt" => "Never had a src" } },
      { "type" => "blockquote", "content" => [ { "type" => "image", "attrs" => { "asset" => asset.id.to_s, "src" => "/assets/stale/old.jpg" } } ] }
    ]

    images = fieldtype("rich_text").pre_process(body)
    sources = [ images.first.dig("attrs", "src"), images.last["content"].first.dig("attrs", "src") ]

    assert_equal [ asset.url, asset.url ], sources
    assert_equal "Never had a src", images.first.dig("attrs", "alt"), "the alt text is the author's, not the asset's"
  end

  test "rich text without sets augments to sanitized HTML" do
    html = fieldtype(:rich_text).augment([ paragraph("Hello <script>x</script>") ])

    assert_equal "<p>Hello &lt;script&gt;x&lt;/script&gt;</p>", html
    assert_nil fieldtype(:rich_text).augment(nil)
  end

  test "images inside rich text count as uses of their asset, so usage, delete protection and cache purges see them" do
    image = ->(id) { { "type" => "image", "attrs" => { "asset" => id, "alt" => "" } } }
    body = [ paragraph("Intro"), image.("7"), { "type" => "bulletList", "content" => [ { "type" => "listItem", "content" => [ image.("9"), image.("7") ] } ] } ]

    assert_equal [ [ "asset", "7" ], [ "asset", "9" ] ], fieldtype(:rich_text).relations(body)
    assert_equal %w[asset:7 asset:9], fieldtype(:rich_text).dependencies(body)
  end

  test "rich text with sets splits into text chunks and augmented sets, skipping disabled ones" do
    body = fieldtype(:rich_text, sets: QUOTE_SET)
    blocks = body.augment([
      paragraph("Intro"),
      set_node({ "type" => "quote", "quote" => "Be kind", "attribution" => "Anon" }),
      set_node({ "type" => "quote", "quote" => "Hidden" }, id: "zzz", enabled: false),
      paragraph("Outro")
    ])

    assert_equal [ "text", "quote", "text" ], blocks.map { |block| block["type"] }
    assert_equal "<p>Intro</p>", blocks.first["text"]
    assert_equal({ "quote" => "Be kind", "attribution" => "Anon", "id" => "abc12345", "type" => "quote" }, blocks[1])
    assert_equal [], body.augment(nil), "themes can always iterate the blocks"
  end

  test "sets accept the grouped config form too" do
    grouped = { "text" => { "display" => "Text", "sets" => QUOTE_SET } }
    assert_equal %w[quote], fieldtype(:rich_text, sets: grouped).sets_config.keys
  end

  test "processing drops the implicit enabled flag and empty values, and an empty doc stores nothing" do
    body = fieldtype(:rich_text, sets: QUOTE_SET)
    stored = body.process([ set_node({ "type" => "quote", "quote" => "Hi", "attribution" => nil }, enabled: true) ])

    assert_equal({ "id" => "abc12345", "values" => { "type" => "quote", "quote" => "Hi" } }, stored.first["attrs"])
    assert_nil body.process([ { "type" => "paragraph" } ])
    assert_nil body.process([])
  end

  test "pre_process gives every set an id and the CP an explicit enabled state, and accepts a whole doc" do
    body = fieldtype(:rich_text, sets: QUOTE_SET)
    editing = body.pre_process({ "type" => "doc", "content" => [ set_node({ "type" => "quote", "quote" => "Hi" }, id: nil) ] })

    assert_equal 8, editing.first.dig("attrs", "id").length
    assert_equal true, editing.first.dig("attrs", "enabled")
  end

  test "empty paragraphs can be trimmed from the ends on save" do
    trimmed = fieldtype(:rich_text, remove_empty_nodes: "trim").process([ { "type" => "paragraph" }, paragraph("Keep"), { "type" => "paragraph" } ])
    assert_equal [ paragraph("Keep") ], trimmed
  end

  test "inline rich text stores bare inline nodes and edits inside a paragraph" do
    inline = fieldtype(:rich_text, inline: true)
    nodes = [ { "type" => "text", "text" => "Hi" } ]

    assert_equal nodes, inline.process([ { "type" => "paragraph", "content" => nodes } ])
    assert_equal [ { "type" => "paragraph", "content" => nodes } ], inline.pre_process(nodes)
  end

  test "rules inside a rich text set point at the set's position in the document" do
    fields = Nibble::Fields.new([ { handle: "body", field: { type: "rich_text", sets: QUOTE_SET } } ], source: "test")
    result = Nibble::Validator.new(fields).validate("body" => [ paragraph("Intro"), set_node({ "type" => "quote", "quote" => "" }) ])

    assert_equal [ "body.1.attrs.values.quote" ], result.errors.keys
  end

  test "set preload gives the CP meta for existing rows and ready-made new rows" do
    meta = fieldtype(:rich_text, { sets: QUOTE_SET }, value: [ set_node({ "type" => "quote", "quote" => "Hi" }) ]).preload

    assert_equal %w[abc12345], meta["existing"].keys
    assert_equal %w[quote], meta["new"].keys
    assert_equal({ "quote" => nil, "attribution" => nil }, meta["defaults"]["quote"])
  end

  test "search text covers the words editors wrote" do
    assert_equal "Hello world", fieldtype(:rich_text).search_text([ paragraph("Hello"), paragraph("world") ])
  end

  test "link passes URLs through and resolves typed links through their registered resolver" do
    resolver = Class.new { def resolve(id) = id == "7" ? { url: "/about", title: "About" } : nil }.new
    Nibble::LinkTypes.register("entry", title: "Entry", resolver:)
    link = fieldtype(:link)

    assert_equal({ "type" => "url", "url" => "https://example.com" }, link.augment("https://example.com"))
    assert_equal({ "type" => "entry", "id" => "7", "url" => "/about", "title" => "About" }, link.augment("entry::7"))
    assert_nil link.augment("entry::404"), "a link to a missing record renders nothing rather than a broken href"
    assert_equal [ [ "entry", "7" ] ], link.relations("entry::7")
    assert_empty link.relations("https://example.com")
  end

  test "list drops blank rows and stores numbers as numbers" do
    assert_equal [ "Mon", 9, 4.5 ], fieldtype(:list).process([ "Mon", "", nil, "9", "4.5" ])
    assert_equal [], fieldtype(:list).pre_process(nil)
  end

  test "seo stores only set keys, normalises noindex, and validates canonical and schema type" do
    seo = fieldtype(:seo)
    assert_equal({ "title" => "Hi", "noindex" => true }, seo.process("title" => "Hi", "description" => "", "noindex" => "1", "bogus" => "x"))
    assert_nil seo.process({})

    fields = Nibble::Fields.new([ { handle: "seo", field: { type: "seo" } } ], source: "test")
    errors = Nibble::Validator.new(fields).validate("seo" => { "canonical" => "http://insecure.test", "schema_type" => "Nope" }).errors
    assert_equal %w[seo.canonical seo.schema_type], errors.keys.sort
  end
end
