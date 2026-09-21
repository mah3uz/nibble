require "test_helper"

# A folder of Markdown, once imported, is an ordinary page: routed, rendered by the theme, cached like the rest.
class NibbleMarkdownPagesTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  setup do
    @folder = Pathname(Dir.mktmpdir("nibble-docs"))
    @folder.join("guides").mkpath
    @folder.join("guides/index.md").write("---\ntitle: Guides\n---\n\nEverything we know.\n")
    @folder.join("guides/testing.md").write("---\ntitle: Testing\n---\n\n# Testing\n\nSee [guides](index.md).\n")
    Nibble::Packages::Folder.new("docs", root: @folder, field: "body", navigation: "docs").call
    Nibble::Records::Entry.kept.each { |entry| Nibble::Lifecycle.call(entry, :publish, {}) }
  end

  test "a page written in Markdown is served by the theme the collection names, as HTML" do
    get Nibble::Records::Entry.live.find_by!(slug: "testing").uri

    assert_response :success
    assert_equal "theme/docs/show", page_props["component"], "the collection's template, like any other page"
    body = page_props["props"]["page"]["body"]
    assert_includes body, "<h1 id=\"testing\">Testing", "Markdown reaches a theme as HTML, not as source"
    assert_includes body, %(href="#{Nibble::Records::Entry.live.find_by!(slug: 'guides').uri}"), "and its links resolve"

    sidebar = page_props["props"]["site"]["navigation"]["docs"]
    assert_equal [ "Guides" ], sidebar.map { |node| node["title"] }
    assert_equal [ "Testing" ], sidebar.sole["children"].map { |node| node["title"] }, "the sidebar a docs theme draws"
  end
end
