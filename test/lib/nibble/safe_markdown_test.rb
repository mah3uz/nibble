require "test_helper"

class Nibble::SafeMarkdownTest < ActiveSupport::TestCase
  test "a label link keeps only web, email, phone and site targets, and gets rel=noopener without a target" do
    html = Nibble::SafeMarkdown.label_html("[a](https://x.test) [b](mailto:a@x.test) [c](tel:+6123) [d](/privacy) [e](#top)")

    assert_equal 5, Nokogiri::HTML5.fragment(html).css("a[href][rel=noopener]").size
    assert_not_includes html, "target"
  end

  test "javascript: and data: links are dropped to their text, in a label and in a note, and raw HTML never survives" do
    [ "[x](javascript:alert(1))", "[x](JaVaScRiPt:alert(1))", "[x](data:text/html;base64,PHNjcmlwdD4=)", "[x](vbscript:msgbox)" ].each do |markdown|
      [ Nibble::SafeMarkdown.label_html(markdown), Nibble::SafeMarkdown.html(markdown) ].compact.each do |html|
        assert_not_includes html, "href", markdown
        assert_includes html, "x", markdown
      end
    end

    html = Nibble::SafeMarkdown.html(%(<script>alert(1)</script><img src=x onerror=alert(1)><a href="/ok" onclick="alert(1)">ok</a> **b**))
    assert_not_includes html, "<script"
    assert_not_includes html, "onerror"
    assert_not_includes html, "onclick"
    assert_not_includes html, "<img"
  end

  test "a note keeps paragraphs, emphasis and lists, and drops headings and images" do
    html = Nibble::SafeMarkdown.html("# Big\n\nOne *two* **three**\n\n- a\n- b\n\n![pic](https://x.test/p.png)")

    assert_includes html, "<em>two</em>"
    assert_includes html, "<strong>three</strong>"
    assert_includes html, "<li>a</li>"
    assert_not_includes html, "<h1"
    assert_not_includes html, "<img"
  end

  test "the plain text of a label is the link text" do
    assert_equal "I agree to the privacy policy", Nibble::SafeMarkdown.label_text("I agree to the [privacy policy](/privacy)")
  end
end
