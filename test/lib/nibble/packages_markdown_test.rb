require "test_helper"

class Nibble::PackagesMarkdownTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  def folder(files)
    dir = Pathname(Dir.mktmpdir("nibble-markdown"))
    files.each do |path, content|
      dir.join(path).dirname.mkpath
      dir.join(path).write(content)
    end
    dir
  end

  def folder_for(dir) = Nibble::Packages::Folder.new("docs", root: dir, field: "body")

  def read(dir, **options)
    reader = Nibble::Packages::MarkdownReader.new(dir, collection: "posts", **options)
    [ reader.documents, reader.errors ]
  end

  test "a file becomes the document an import already knows how to write" do
    dir = folder("guides/testing.md" => "---\ntitle: Testing\norder: 2\n---\n\n# Testing\n\nHow we test.\n",
                 "guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n")

    documents, errors = read(dir)

    assert_empty errors
    testing = documents.find { |doc| doc.slug == "testing" }
    assert_equal "posts/guides/testing", testing.key, "the path is the key, so a page keeps its place"
    assert_equal "posts/guides", testing.parent_key, "a folder's index.md is the page its files sit under"
    assert_equal "Testing", testing.data["title"], "frontmatter is fields"
    assert_equal "# Testing\n\nHow we test.", testing.data["body"], "the body is the Markdown, frontmatter removed"
    assert_equal 2, testing.data["order"]
  end

  test "the field the body lands in is the collection's to choose" do
    dir = folder("note.md" => "Just text.\n")

    documents, = read(dir, field: "notes")

    assert_equal "Just text.", documents.sole.data["notes"]
  end

  test "a page with nowhere to sit is reported rather than imported" do
    dir = folder("guides/testing.md" => "Orphan.\n")

    documents, errors = read(dir)

    assert_empty documents
    assert_match(/guides\/ has no index.md/, errors.sole)
  end

  test "an index at the root would have no slug, and says so" do
    dir = folder("index.md" => "Home.\n")

    documents, errors = read(dir)

    assert_empty documents
    assert_match(/no slug/, errors.sole)
  end

  test "a folder of Markdown imports as entries, through the pipeline a package already uses" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n",
                 "guides/testing.md" => "---\ntitle: Testing\n---\n\nHow we test.\n")
    reader = Nibble::Packages::MarkdownReader.new(dir, collection: "docs", field: "body")

    report = Nibble::Packages::Importer.new(dir, reader:).call

    assert report.ok?, report.errors.join("\n")
    testing = Nibble::Records::Entry.find_by!(slug: "testing")
    assert_equal "How we test.", testing.values["body"]
    assert_equal "guides", testing.parent&.slug, "the folder is the page above it"
    assert_equal "Testing", testing.title, "frontmatter reaches the columns an import sets, not only fields"
  end

  test "the folder decides what exists: a page whose file has gone is trashed, not left live" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n",
                 "guides/testing.md" => "---\ntitle: Testing\n---\n\nHow we test.\n")
    folder_for(dir).call

    dir.join("guides/testing.md").delete
    result = folder_for(dir).call

    assert result.ok?, result.report.errors.join("\n")
    assert_equal 1, result.trashed.size, "the page whose file went, and only that page"
    assert_nil Nibble::Records::Entry.kept.find_by(slug: "testing")
    assert Nibble::Records::Entry.kept.find_by(slug: "guides"), "the pages still written are left alone"
  end

  test "running it again changes nothing, which is what makes it safe at every deploy" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n")
    first = folder_for(dir).call

    second = folder_for(dir).call

    assert_equal 1, first.report.created.size
    assert_empty second.report.created
    assert_empty second.trashed
    assert_equal "Everything.", Nibble::Records::Entry.kept.sole.values["body"]
  end
end
