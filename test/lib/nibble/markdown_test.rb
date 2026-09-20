require "test_helper"

class Nibble::MarkdownTest < ActiveSupport::TestCase
  DOC = <<~MD
    # Title

    Text with **bold**, `code` and ~~gone~~.

    > [!NOTE]
    > An alert.

    - [x] done

    | A | B |
    |---|---|
    | 1 | 2 |

    ```ruby
    puts 1
    ```

    A footnote[^1].

    [^1]: The note.
  MD

  test "the features the documentation is written in all survive rendering" do
    html = Nibble::Markdown.render(DOC)

    assert_includes html, "<h1 id=\"title\"", "headings need ids, or nothing can link into a page"
    assert_includes html, "<del>gone</del>"
    assert_includes html, "markdown-alert-note", "> [!NOTE] is how the docs write a callout"
    assert_includes html, %(<input type="checkbox" checked)
    assert_includes html, "<table>"
    assert_includes html, %(<code class="language-ruby">), "the class every highlighter looks for"
    assert_includes html, "footnote-ref"
  end

  test "code is not highlighted into inline styles, which a stylesheet does better" do
    html = Nibble::Markdown.render("```ruby\nputs 1\n```\n")

    assert_not_includes html, "style=", "comrak highlights with inline styles in a theme of its own choosing"
  end

  test "a paragraph wrapped across lines is one paragraph, not a stack of breaks" do
    html = Nibble::Markdown.render("a sentence that continues\nonto the next line\n")

    assert_not_includes html, "<br", "our documents and changelog wrap at a column; that is not a line break"
  end

  test "raw HTML never survives, which is what lets our own documents render unfiltered" do
    html = Nibble::Markdown.render("<script>alert(1)</script>\n\n<div onclick=\"x\">hi</div>\n")

    assert_not_includes html, "<script"
    assert_not_includes html, "onclick"
  end

  test "sanitising keeps what Markdown needs, which the rich text allowlist would have destroyed" do
    html = Nibble::Markdown.render(DOC, sanitize: true)

    assert_includes html, "<h1 id=\"title\"", "RichText::Sanitizer starts at h2 and strips id"
    assert_includes html, "<del>gone</del>"
    assert_includes html, "markdown-alert-note"
    assert_includes html, %(<input type="checkbox")
    assert_includes html, %(<code class="language-ruby">)
  end

  test "sanitising still refuses a link that would run code" do
    html = Nibble::Markdown.render("[x](javascript:alert(1))\n", sanitize: true)

    assert_not_includes html, "javascript:"
  end

  test "front matter is read, and rubbish in it does not raise" do
    assert_equal({ "title" => "Hi", "order" => 2 }, Nibble::Markdown.front_matter("---\ntitle: Hi\norder: 2\n---\n\nBody\n"))
    assert_empty Nibble::Markdown.front_matter("No front matter here\n")
    assert_empty Nibble::Markdown.front_matter("---\n: : :\n---\n")
  end
end
