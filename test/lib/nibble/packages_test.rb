require "test_helper"

class Nibble::PackagesTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  DEMO = Rails.root.join("test/nibble_packages/demo")

  def import(dir = DEMO, **options) = Nibble::Packages::Importer.new(dir, **options).call
  def entry(slug) = Nibble::Records::Entry.find_by!(slug:)

  def package(files)
    dir = Pathname(Dir.mktmpdir("nibble-package"))
    files.each do |path, content|
      dir.join(path).dirname.mkpath
      dir.join(path).write(content.is_a?(String) ? content : content.deep_stringify_keys.to_yaml)
    end
    dir
  end

  test "an inline image in a body lands on the asset its path names, not on the path itself" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "photo.jpg")
    asset = Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:), :create, { "folder" => "site" }).record
    image = { "type" => "image", "attrs" => { "asset" => "site/photo.jpg", "alt" => "A desk" } }
    dir = package("collections/posts/en/pictured.yml" => { title: "Pictured", status: "draft", body: [ image ] })

    report = import(dir)

    assert report.ok?, report.errors.join("\n")
    assert_equal asset.id.to_s, entry("pictured").values["body"].first.dig("attrs", "asset")
  end

  test "a package creates linked content with natural-key references resolved to records" do
    report = import
    assert report.ok?, report.errors.join("\n")

    grids = entry("grids")
    assert_equal [ "published", "/blog/grids" ], [ grids.status, grids.uri ]
    assert_equal [ Nibble::Records::Term.find_by!(slug: "design").id.to_s ], grids.values["topics"]
    assert_equal [ entry("colour-theory").id.to_s ], grids.values["related"]
    assert_equal "draft", entry("colour-theory").status
    assert_equal entry("about").id, entry("team").parent_id
    assert_equal "/about/team", entry("team").uri
    assert_equal "Demo site", Nibble::Records::GlobalSet.find_by!(handle: "site").data["name"]
    assert_equal [ entry("about").id, "url" ], Nibble::Records::NavigationTree.find_by!(handle: "main").tree.then { |tree| [ tree[0]["id"], tree[1]["type"] ] }
    assert_equal "/blog/grids", Nibble::Records::Redirect.find_by!(from: "/old-grids").to
    assert_equal "import", grids.revisions.last.kind
  end

  test "importing the same package again changes nothing" do
    import
    counts = [ Nibble::Records::Entry.count, Nibble::Records::Term.count, Nibble::Records::Redirect.count ]

    report = import
    assert report.ok?, report.errors.join("\n")
    assert_empty report.created
    assert_equal counts, [ Nibble::Records::Entry.count, Nibble::Records::Term.count, Nibble::Records::Redirect.count ]
  end

  test "every problem is reported with its file, and nothing is written when any file is invalid" do
    dir = package(
      "collections/posts/en/ok.yml" => { title: "Fine", published_at: "2026-01-01T00:00:00Z" },
      "collections/posts/en/no-date.yml" => { title: "Undated" },
      "collections/posts/en/bad-ref.yml" => { title: "Refs", published_at: "2026-01-01T00:00:00Z", topics: [ "topics/missing" ] },
      "collections/nope/en/x.yml" => { title: "X" },
      "collections/posts/en/extra.yml" => { title: "Extra", published_at: "2026-01-01T00:00:00Z", colour: "red" },
      "navigation/main/en.yml" => { tree: [ { entry: "pages/missing" } ] },
      "junk/file.yml" => { a: 1 }
    )
    before = Nibble::Records::Entry.count

    report = import(dir)
    messages = report.errors.join("\n")
    assert_match "collections/posts/en/no-date.yml: published_at is required", messages
    assert_match "collections/posts/en/bad-ref.yml: topics:", messages
    assert_match "collections/nope/en/x.yml: no collection 'nope'", messages
    assert_match "collections/posts/en/extra.yml: 'colour' isn't a field", messages
    assert_match "navigation/main/en.yml: link to unknown entry 'pages/missing'", messages
    assert_match "junk/file.yml: unknown folder 'junk'", messages
    assert_equal before, Nibble::Records::Entry.count
  end

  test "a dry run validates without writing, and unsupported modes are refused" do
    assert import(dry_run: true).ok?
    assert_equal 0, Nibble::Records::Entry.where(slug: "grids").count
    assert_raises(Nibble::Error) { Nibble::Packages::Importer.new(DEMO, mode: "replace") }
  end
end
