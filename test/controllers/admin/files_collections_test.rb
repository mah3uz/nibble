require "test_helper"

class Admin::FilesCollectionsTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  setup do
    write({ "docs/index.md" => "---\nid: docs-home\ntitle: Docs\n---\n\nStart here.\n",
            "docs/guides/index.md" => "---\nid: guides\ntitle: Guides\norder: 1\n---\n\nAll of them.\n",
            "docs/guides/testing.md" => "---\nid: testing\ntitle: Testing\norder: 1\n---\n\nHow we test.\n",
            "docs/install.md" => "---\nid: install\ntitle: Installing\norder: 0\n---\n\nClone it.\n" })
    sign_in_as users(:editor)
  end

  def write(files)
    dir = Pathname(Dir.mktmpdir("nibble-content"))
    files.each do |path, text|
      dir.join(path).dirname.mkpath
      dir.join(path).write(text)
    end
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "url" => "https://example.test",
      "locales" => [ { "code" => "en", "default" => true } ], "reserved_paths" => [ "/admin" ] },
      themes_path: Rails.root.join("test/nibble_themes"),
      site_schema_path: Rails.root.join("test/nibble_themes/no_site_schema"), content_path: dir,
      published_path: Pathname(Dir.mktmpdir("nibble-published")))
    Nibble.reset_schema!
    Nibble::Files.reload!
  end

  def props = page_props["props"]

  # A folder has no rows, so a listing that only reads rows shows an empty collection that is serving pages.
  test "a folder's pages are listed, because they are the collection" do
    get "/admin/collections/docs"
    assert_response :success
    listing = props["listing"]

    assert_equal [ "Docs", "Guides", "Installing", "Testing" ], listing["rows"].map { |row| row["title"] }.sort
    assert_equal "/admin/collections/docs/entries/testing/edit", listing["rows"].find { |row| row["title"] == "Testing" }["edit_url"]
    assert_nil props["create"], "a page made here would answer to nobody, so nothing offers to make one"
    assert_nil listing["create"]
    assert_empty listing["actions"]
    assert(listing["rows"].all? { |row| row["actions"].empty? }, "publishing or trashing a file's page changes nothing anyone sees")
  end

  test "search narrows a folder's listing the way it narrows rows" do
    get "/admin/collections/docs", params: { q: "test" }
    assert_equal [ "Testing" ], props["listing"]["rows"].map { |row| row["title"] }
  end

  # The folders are the structure, so the tree has to be theirs rather than a parent_id nobody wrote.
  test "the tree view follows the folders" do
    get "/admin/collections/docs", params: { view: "tree" }
    guides = props["tree"].find { |node| node["title"] == "Guides" }

    assert_equal [ "Testing" ], guides["children"].map { |node| node["title"] }
    assert_equal "/admin/collections/docs/entries/guides/edit", guides["edit_url"]
  end

  # Somebody who finds a typo needs to know where the page is written, and must not be offered a save that is thrown away.
  test "a page written as a file opens read-only and names its file" do
    get "/admin/collections/docs/entries/testing/edit"
    assert_response :success

    assert_equal "Testing", props["values"]["title"]
    assert_includes props["values"]["body"], "How we test."
    assert_match %r{docs/guides/testing\.md\z}, props["source"]["file"]
    assert_equal({ "edit" => false, "publish" => false, "delete" => false }, props["can"].slice("edit", "publish", "delete"))
    assert_equal "https://example.test/docs/guides/testing", props["meta"]["permalink"]
  end

  test "an id no file in this collection declares is not found" do
    get "/admin/collections/docs/entries/nothing/edit"
    assert_response :not_found
  end

  # The public site builds this menu from the folders, so a tree saved here would be ignored by every page.
  test "a menu built from files shows the folders' tree and saves nothing" do
    get "/admin/navigation/docs/edit"
    assert_response :success

    assert_equal [ [ "Installing", 0 ], [ "Guides", 0 ], [ "Testing", 1 ] ],
      props["source"]["links"].map { |link| [ link["title"], link["depth"] ] }
    assert_match %r{docs\z}, props["source"]["folder"]

    assert_no_difference -> { Nibble::Records::NavigationTree.count } do
      patch "/admin/navigation/docs", params: { tree: [ { title: "Sneaked in", link: { type: "url", url: "/x" }, children: [] } ] }
    end
    assert_redirected_to "/admin/navigation/docs/edit"
  end

  # A folder's pages are live the moment they are deployed; counting only rows showed the collection as empty.
  test "the dashboard counts a folder's pages as published" do
    docs = Nibble::Cp::Widgets.data(users(:editor))["content_mix"]["collections"].find { |item| item["handle"] == "docs" }

    assert_equal 4, docs["counts"]["published"]
    assert_equal 4, docs["total"]
  end
end
