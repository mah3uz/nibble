require "test_helper"

class RichText::RendererTest < ActiveSupport::TestCase
  def doc(*content)
    { "type" => "doc", "content" => content }
  end

  def text(value, marks = nil)
    { "type" => "text", "text" => value, "marks" => marks }.compact
  end

  def paragraph(*content)
    { "type" => "paragraph", "content" => content }
  end

  def render(*content)
    RichText::Renderer.call(doc(*content))
  end

  test "renders the allowed formatting editors use" do
    html = render(
      { "type" => "heading", "attrs" => { "level" => 2 }, "content" => [ text("Why it works") ] },
      paragraph(text("Fast "), text("approvals", [ { "type" => "bold" } ]), text(" and "), text("terms", [ { "type" => "link", "attrs" => { "href" => "https://example.com/how-it-works" } } ])),
      { "type" => "bulletList", "content" => [ { "type" => "listItem", "content" => [ paragraph(text("One")) ] } ] },
      { "type" => "blockquote", "content" => [ paragraph(text("Quote")) ] },
      { "type" => "image", "attrs" => { "src" => "https://cdn.example.com/a.jpg", "alt" => "Clinic", "width" => 800, "height" => 600 } },
      { "type" => "table", "content" => [ { "type" => "tableRow", "content" => [ { "type" => "tableHeader", "attrs" => { "colspan" => 2 }, "content" => [ paragraph(text("H")) ] } ] } ] }
    )

    assert_includes html, "<h2>Why it works</h2>"
    assert_includes html, "<strong>approvals</strong>"
    assert_includes html, %(<a href="https://example.com/how-it-works">terms</a>)
    assert_includes html, "<ul><li><p>One</p></li></ul>"
    assert_includes html, "<blockquote><p>Quote</p></blockquote>"
    assert_includes html, %(<img src="https://cdn.example.com/a.jpg" alt="Clinic" width="800" height="600">)
    assert_includes html, %(<table><thead><tr><th colspan="2">H</th></tr></thead><tbody></tbody></table>)
  end

  test "a resized table publishes at the widths the editor set" do
    row = { "type" => "tableRow", "content" => [
      { "type" => "tableHeader", "attrs" => { "colwidth" => [ 240 ] }, "content" => [ paragraph(text("Wide")) ] },
      { "type" => "tableHeader", "attrs" => { "colwidth" => nil }, "content" => [ paragraph(text("Auto")) ] }
    ] }

    html = render({ "type" => "table", "content" => [ row ] })

    assert_includes html, %(<colgroup><col width="240"><col></colgroup>),
                    "without this the page ignores a resize the editor shows"
    assert_equal html, RichText::Sanitizer.sanitize(html), "the sanitizer must not strip the widths it just rendered"
  end

  test "headings are limited to h2-h4 so the page keeps a single h1" do
    assert_includes render({ "type" => "heading", "attrs" => { "level" => 1 }, "content" => [ text("A") ] }), "<h2>A</h2>"
    assert_includes render({ "type" => "heading", "attrs" => { "level" => 6 }, "content" => [ text("B") ] }), "<h4>B</h4>"
  end

  test "text that looks like HTML is escaped, never interpreted" do
    html = render(paragraph(text("<script>alert(1)</script><img src=x onerror=alert(1)>")))
    assert_not_includes html, "<script"
    assert_not_includes html, "<img"
    assert_includes html, "&lt;script&gt;"
  end

  test "javascript: and data: URLs are removed from links and images" do
    %w[javascript:alert(1) JavaScript:alert(1) data:text/html;base64,PHNjcmlwdD4= //evil.example/x].each do |url|
      html = render(
        paragraph(text("click", [ { "type" => "link", "attrs" => { "href" => url } } ])),
        { "type" => "image", "attrs" => { "src" => url, "alt" => "x" } }
      )
      assert_no_match(/href=|src=/, html, "#{url} survived: #{html}")
    end
  end

  test "attribute values cannot break out of their quotes" do
    html = render(paragraph(text("x", [ { "type" => "link", "attrs" => { "href" => %(https://a.com/" onmouseover="alert(1)) } } ])))
    link = Nokogiri::HTML5.fragment(html).at_css("a")
    assert_equal [ "href" ], link.attributes.keys
  end

  test "unknown node types (e.g. raw html) are dropped" do
    assert_equal "", render({ "type" => "html", "content" => [ text("<script>alert(1)</script>") ] })
  end

  test "new-tab links get noopener to prevent reverse tabnabbing" do
    html = render(paragraph(text("x", [ { "type" => "link", "attrs" => { "href" => "https://a.com", "target" => "_blank" } } ])))
    assert_includes html, %(rel="noopener noreferrer")
  end

  test "sanitizer strips script, style, iframes and on* attributes from raw HTML" do
    dirty = %(<p onclick="alert(1)">Hi</p><script>alert(1)</script><style>p{}</style><iframe src="https://x"></iframe><a href="javascript:alert(1)">x</a><img src="/a.jpg" onerror="alert(1)">)
    dom = Nokogiri::HTML5.fragment(RichText::Sanitizer.sanitize(dirty))
    assert_empty dom.css("script, style, iframe")
    assert_empty dom.xpath(".//@*[starts-with(name(), 'on')]")
    assert_nil dom.at_css("a")["href"]
    assert_equal "Hi", dom.at_css("p").text
    assert_equal({ "src" => "/a.jpg" }, dom.at_css("img").attributes.transform_values(&:value))
  end

  test "library images render the preset's sizes and fall back to the asset's alt text" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "body.jpg")
    asset = Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:), :create, { "alt" => "Clinic" }).record
    img = ->(attrs) { Nokogiri::HTML5.fragment(RichText::Renderer.call({ "type" => "doc", "content" => [ { "type" => "image", "attrs" => attrs } ] }, image_preset: "content")).at_css("img") }

    rendered = img.({ "asset" => asset.id, "alt" => "" })
    assert_equal [ asset.url("content"), "Clinic", "lazy" ], %w[src alt loading].map { |name| rendered[name] }
    assert_equal Nibble::Assets.preset("content")["srcset"].size, rendered["srcset"].split(",").size
    assert_equal "Front desk", img.({ "asset" => asset.id, "alt" => "Front desk" })["alt"]
  end

  test "srcset with an unsafe URL is removed" do
    dom = Nokogiri::HTML5.fragment(RichText::Sanitizer.sanitize(%(<img src="/a.jpg" srcset="/a.jpg 1x, javascript:alert(1) 2x" alt="">)))
    assert_nil dom.at_css("img")["srcset"]
  end
end
