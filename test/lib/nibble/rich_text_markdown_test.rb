require "test_helper"

class Nibble::RichTextMarkdownTest < ActiveSupport::TestCase
  Converter = Nibble::RichTextMarkdown

  test "Markdown an app writes becomes the editor's nodes, and reads back the same" do
    markdown = "## Heading\n\nSome **bold**, *italic*, `code` and [a link](https://example.com).\n\n- one\n- two\n   - nested\n\n" \
               "3. three\n4. four\n\n> quoted\n\n```ruby\nputs 1\n```\n\n---\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n\n![Cover](asset:12)"
    nodes = Converter.to_nodes(markdown)

    assert_equal %w[heading paragraph bulletList orderedList blockquote codeBlock horizontalRule table image], nodes.map { |node| node["type"] }
    assert_equal nodes, Converter.to_nodes(Converter.to_markdown(nodes)), "reading it back and saving it again changes nothing"
  end

  test "a link that would run script keeps its words and loses its link" do
    nodes = Converter.to_nodes("[click](javascript:alert(1)) and [data](data:text/html,x)")

    html = RichText::Renderer.call({ "type" => "doc", "content" => nodes })
    assert_no_match(/javascript:|data:/, html)
    assert_match "click", html
  end

  test "images from other sites are dropped, so a preview can't call out to them" do
    nodes = Converter.to_nodes("![tracker](https://tracker.example/pixel.png)\n\n![ours](asset:3)")

    assert_equal [ { "type" => "image", "attrs" => { "asset" => "3", "alt" => "ours" } } ], nodes
  end

  test "raw HTML stays text, never markup" do
    html = RichText::Renderer.call({ "type" => "doc", "content" => Converter.to_nodes("<script>alert(1)</script>\n\nhi <b onclick=x>there</b>") })

    assert_no_match(/<script|onclick=/, html)
  end

  test "content Markdown can't express is left as editor JSON instead of losing it" do
    nodes = [ { "type" => "set", "attrs" => { "values" => { "type" => "quote" } } } ]

    assert_nil Converter.to_markdown(nodes)
  end
end
