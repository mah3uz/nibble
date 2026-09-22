require "test_helper"

class Nibble::FilesTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  teardown { Nibble::Files.reload! }

  def content(files)
    dir = Pathname(Dir.mktmpdir("nibble-content"))
    files.each do |path, text|
      dir.join(path).dirname.mkpath
      dir.join(path).write(text)
    end
    dir
  end

  def page(id:, title:, body: "Words.", **front)
    front = { "id" => id, "title" => title }.merge(front.stringify_keys)
    "---\n#{front.to_yaml.delete_prefix("---\n")}---\n\n#{body}\n"
  end

  def index_for(files)
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "locales" => [ { "code" => "en", "default" => true } ] },
      themes_path: Rails.root.join("test/nibble_themes"),
      site_schema_path: Rails.root.join("test/nibble_themes/no_site_schema"),
      content_path: content(files))
    Nibble.reset_schema!
    Nibble::Files.reload!
  end

  # A page's address is where its file sits, so moving the file is the only thing that moves the page.
  test "a folder's shape is the address, and a folder's own index.md answers for the folder" do
    index = index_for("docs/index.md" => page(id: "docs-home", title: "Docs"),
                      "docs/users/index.md" => page(id: "users", title: "Users"),
                      "docs/users/installing.md" => page(id: "installing", title: "Installing"))

    assert_equal %w[/docs /docs/users /docs/users/installing], index.pages.map(&:uri).sort
    assert_equal "Installing", index.page("/docs/users/installing").title
  end

  # The id is what anything pointing at a page holds, so it must not depend on where the file sits.
  test "moving a file keeps its id and changes only its address" do
    before = index_for("docs/index.md" => page(id: "docs-home", title: "Docs"),
                       "docs/installing.md" => page(id: "installing", title: "Installing"))
    after = index_for("docs/index.md" => page(id: "docs-home", title: "Docs"),
                      "docs/users/index.md" => page(id: "users", title: "Users"),
                      "docs/users/installing.md" => page(id: "installing", title: "Installing"))

    assert_equal "/docs/installing", before.find("installing").uri
    assert_equal "/docs/users/installing", after.find("installing").uri, "the address follows the file"
    assert after.find("installing"), "and the id does not"
  end

  # Editing must not retire a page's identity, or every link to it would break on a typo fix.
  test "editing a page changes its digest and not its id" do
    before = index_for("docs/index.md" => page(id: "docs-home", title: "Docs", body: "First."))
    after = index_for("docs/index.md" => page(id: "docs-home", title: "Docs", body: "Second."))

    assert_equal before.find("docs-home").id, after.find("docs-home").id
    assert_not_equal before.find("docs-home").digest, after.find("docs-home").digest
  end

  test "a page without an id is a problem, and the rest of the folder still reads" do
    index = index_for("docs/index.md" => page(id: "docs-home", title: "Docs"),
                      "docs/stray.md" => "---\ntitle: Stray\n---\n\nWords.\n")

    assert_not index.ok?
    assert_equal 1, index.pages.size
    assert_match "has no id", index.problems.sole.to_s
  end

  # A build is where content mistakes are named, so an unknown blueprint cannot be what takes the index down.
  test "a page naming a blueprint the schema has not got is a problem, not a crash" do
    index = index_for("docs/index.md" => page(id: "docs-home", title: "Docs"),
                      "docs/odd.md" => page(id: "odd", title: "Odd", blueprint: "nowhere"))

    assert_not index.ok?
    assert_equal 1, index.pages.size
    assert_match "nowhere", index.problems.sole.to_s
  end

  # Two pages at one address is a content mistake that must be named, not resolved by whichever read first.
  test "two pages claiming one id are reported" do
    index = index_for("docs/index.md" => page(id: "same", title: "Docs"),
                      "docs/other.md" => page(id: "same", title: "Other"))

    assert_not index.ok?
    assert_match "share the same id", index.problems.sole.to_s
  end

  test "a page under a folder with no index.md has nowhere to sit" do
    index = index_for("docs/index.md" => page(id: "docs-home", title: "Docs"),
                      "docs/users/installing.md" => page(id: "installing", title: "Installing"))

    assert_match "has no index.md", index.problems.sole.to_s
  end

  # A link between files survives either of them moving, which a link written as an address would not.
  test "a link to another file becomes that page's address" do
    index = index_for("docs/index.md" => page(id: "docs-home", title: "Docs", body: "See [Installing](users/installing.md)."),
                      "docs/users/index.md" => page(id: "users", title: "Users"),
                      "docs/users/installing.md" => page(id: "installing", title: "Installing"))

    assert_equal "See [Installing](/docs/users/installing).", index.page("/docs").body
  end

  # Only what the index found under content/ can ever be pointed at, so a path out of it names nothing.
  test "only files found under the content folder are known" do
    index = index_for("docs/index.md" => page(id: "docs-home", title: "Docs"), "docs/diagram.png" => "bytes")

    assert index.file("docs/diagram.png"), "a file inside is found"
    assert_nil index.file("../../etc/passwd")
    assert_nil index.file("docs/../../../etc/passwd")
    assert_nil index.file("/etc/passwd")
    assert_nil index.file("docs/index.md"), "a page is not something a page can point at"
  end

  test "the tree follows the folders, ordered by what the frontmatter says" do
    index = index_for("docs/index.md" => page(id: "docs-home", title: "Docs"),
                      "docs/second.md" => page(id: "second", title: "Second", order: 2),
                      "docs/first.md" => page(id: "first", title: "First", order: 1))

    assert_equal %w[First Second], index.tree("docs").map { |link| link["title"] }
  end

  # Link declares children as always there, so a theme that walks them cannot be made to check for a leaf first.
  test "every link in the tree carries children, whether or not it has any" do
    index = index_for("docs/index.md" => page(id: "docs-home", title: "Docs"),
                      "docs/leaf.md" => page(id: "leaf", title: "Leaf"),
                      "docs/section/index.md" => page(id: "section", title: "Section"),
                      "docs/section/child.md" => page(id: "child", title: "Child"))

    links = index.tree("docs")

    assert_equal [ [], [ "Child" ] ], links.map { |link| link.fetch("children").map { |child| child["title"] } }
  end
end
