require "test_helper"

class Nibble::PackagesNavigationTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  Tree = Nibble::Records::NavigationTree

  setup do
    use_site_addresses(apply_url: "https://apply.example.test/one")
    @nibble_themes.join("records", "schema", "navigation", "full.yml").write({
      "title" => "Full", "collections" => [ "articles" ], "taxonomies" => [ "tags" ], "headings" => true, "globals" => [ "site" ],
      "assets" => true,
      "item_fields" => [ { "handle" => "badge", "field" => { "type" => "text" } },
                         { "handle" => "featured", "field" => { "type" => "toggle" } },
                         { "handle" => "related", "field" => { "type" => "entries", "collections" => [ "articles" ] } } ]
    }.to_yaml)
    Nibble.reset_schema!
  end

  def article(title) = publish_entry(create_entry("articles", { "title" => title })).reload
  def menu = Tree.find_by!(handle: "full", locale: "en")
  def save!(tree) = lifecycle(Tree.find_or_initialize_by(handle: "full", locale: "en"), :save, "tree" => tree).tap { |result| assert result.ok?, result.errors.inspect }
  def import(dir, **options) = Nibble::Packages::Importer.new(dir, **options).call.tap { |report| assert report.ok?, report.errors.join("\n") }
  def read(dir, relative) = YAML.safe_load_file(dir.join(relative))

  def export
    dir = Pathname(Dir.mktmpdir("nibble-export"))
    Nibble::Packages::Exporter.new(dir).call
    dir
  end

  def package(files)
    dir = Pathname(Dir.mktmpdir("nibble-package"))
    files.each do |path, content|
      dir.join(path).dirname.mkpath
      dir.join(path).write(content.deep_stringify_keys.to_yaml)
    end
    dir
  end

  # Menus don't validate query items yet, so one is saved as a heading would be.
  def accepting_query_items
    original = Tree.method(:kind)
    Tree.define_singleton_method(:kind) { |node| node["kind"] == "query" ? "heading" : original.call(node) }
    yield
  ensure
    Tree.define_singleton_method(:kind, original)
  end

  def full_tree(post:, other:, tag:, asset:)
    [ { "kind" => "heading", "title" => "Company", "children" => [
        { "type" => "entry", "id" => post.id, "title" => "Post", "new_tab" => true, "children" => [] },
        { "type" => "global", "ref" => "global:site.apply_url", "title" => "Apply", "hidden" => true, "children" => [] }
      ] },
      { "type" => "asset", "id" => asset.id, "title" => "Prices",
        "fields" => { "badge" => "New", "featured" => true, "related" => [ other.id.to_s ] }, "children" => [] },
      { "type" => "term", "id" => tag.id, "title" => "Ruby", "children" => [] },
      { "kind" => "query", "title" => "Latest",
        "query" => { "collection" => "articles", "parent" => post.id, "term" => { "taxonomy" => "tags", "id" => tag.id }, "sort" => "title", "limit" => 3 },
        "children" => [] } ]
  end

  def wipe_content!
    [ Nibble::Records::Relation, Nibble::Records::Revision, Nibble::Records::Draft, Tree, Nibble::Records::Entry,
      Nibble::Records::Term, Nibble::Records::Asset, Nibble::Records::GlobalSet ].each(&:delete_all)
  end

  test "every kind of menu item survives an export and an import into a fresh database, with its references found again" do
    accepting_query_items do
      records = { post: article("Post"), other: article("Other"), tag: create_term("Ruby"), asset: create_asset({ "title" => "Price list" }) }
      save!(full_tree(**records))
      dir = export

      assert_equal [
        { "kind" => "heading", "title" => "Company", "children" => [
          { "entry" => "articles/post", "title" => "Post", "new_tab" => true },
          { "ref" => "global:site.apply_url", "title" => "Apply", "hidden" => true }
        ] },
        { "asset" => "photo.jpg", "title" => "Prices", "fields" => { "badge" => "New", "featured" => true, "related" => [ "articles/other" ] } },
        { "term" => "tags/ruby", "title" => "Ruby" },
        { "kind" => "query", "title" => "Latest",
          "query" => { "collection" => "articles", "parent" => "articles/post", "term" => { "taxonomy" => "tags", "id" => "tags/ruby" }, "sort" => "title", "limit" => 3 } }
      ], read(dir, "navigation/full/en.yml")["tree"], "a package names records by key, since their ids mean nothing on the site importing it"

      dir.join("assets").mkpath
      dir.join("assets", "photo.jpg").binwrite(records[:asset].blob.download)
      wipe_content!
      import(dir)

      fresh = { post: Nibble::Records::Entry.find_by!(slug: "post"), other: Nibble::Records::Entry.find_by!(slug: "other"),
                tag: Nibble::Records::Term.find_by!(slug: "ruby"), asset: Nibble::Records::Asset.kept.find_by!(filename: "photo.jpg") }
      assert_not_equal records[:post].id, fresh[:post].id, "the fresh database gave the records new ids"
      assert_equal full_tree(**fresh), menu.tree
    end
  end

  test "importing a package again leaves the menu as it is, even where a save stores a value differently from how the package spells it" do
    post = article("Post")
    other = article("Other")
    dir = package("navigation/full/en.yml" => { tree: [
      { kind: "heading", title: "Company", children: [ { entry: "articles/post", new_tab: true } ] },
      { url: "/jobs", title: "Jobs", hidden: true, fields: { badge: "Hiring", featured: 1, related: [ "articles/other" ] } }
    ] })

    import(dir, mode: "update")
    stored = menu.tree
    assert_equal [ "heading", post.id, true ], [ stored[0]["kind"], stored[0]["children"][0]["id"], stored[0]["children"][0]["new_tab"] ]
    assert_equal({ "badge" => "Hiring", "featured" => true, "related" => [ other.id.to_s ] }, stored[1]["fields"])

    report = nil
    assert_no_difference -> { menu.revisions.count } do
      report = import(dir, mode: "update")
    end
    assert_includes report.skipped, "navigation/full/en.yml"
    assert_equal stored, menu.tree
  end

  test "a package written before menus carried more than links imports exactly as it always has" do
    post = article("Post")
    other = article("Other")
    dir = package("navigation/full/en.yml" => { tree: [
      { entry: "articles/post", children: [ { entry: "articles/other", title: "Other one" } ] },
      { url: "https://example.org", title: "Elsewhere" }
    ] })

    import(dir)

    assert_equal [ { "type" => "entry", "id" => post.id, "children" => [ { "type" => "entry", "id" => other.id, "title" => "Other one", "children" => [] } ] },
                   { "type" => "url", "url" => "https://example.org", "title" => "Elsewhere", "children" => [] } ], menu.tree
    assert_equal read(dir, "navigation/full/en.yml"), read(export, "navigation/full/en.yml"), "a plain menu exports as it did, so a package kept in git doesn't change"
  end

  test "a preview of a menu linking to a file the package brings writes nothing and still lists the menu" do
    dir = package("navigation/full/en.yml" => { tree: [ { asset: "files/prices.jpg", title: "Prices" }, { url: "/a", title: "A" } ] })
    dir.join("assets.yml").write([ { "path" => "files/prices.jpg", "mime" => "image/jpeg" } ].to_yaml)
    dir.join("assets", "files").mkpath
    FileUtils.cp(file_fixture("photo.jpg"), dir.join("assets", "files", "prices.jpg"))

    report = Nibble::Packages::Importer.new(dir).preview

    assert report.ok?, report.errors.join("\n")
    assert_includes report.created, "navigation/full/en.yml"
    assert_nil Tree.find_by(handle: "full")
    assert_equal 0, Nibble::Records::Asset.count
  end

  test "a reference the package can't resolve is reported against its file, and nothing is imported" do
    dir = package("navigation/full/en.yml" => { tree: [
      { asset: "nowhere/missing.pdf", title: "Prices" },
      { kind: "query", title: "Latest", query: { collection: "articles", parent: "articles/missing", term: { taxonomy: "tags", id: "tags/missing" } } },
      { url: "/a", title: "A", fields: { related: [ "articles/missing" ], colour: "red" } }
    ] })

    report = Nibble::Packages::Importer.new(dir).call
    messages = report.errors.join("\n")

    assert_match "navigation/full/en.yml: link to unknown asset 'nowhere/missing.pdf'", messages
    assert_match "navigation/full/en.yml: query names unknown entry 'articles/missing'", messages
    assert_match "navigation/full/en.yml: query names unknown term 'tags/missing'", messages
    assert_match "navigation/full/en.yml: related:", messages
    assert_match "navigation/full/en.yml: 'colour' isn't an item field of full", messages
    assert_nil Tree.find_by(handle: "full")
  end
end
