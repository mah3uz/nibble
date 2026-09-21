require "test_helper"

class Nibble::PackagesExportTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  DEMO = Rails.root.join("test/nibble_packages/demo")

  def export(**options)
    dir = Pathname(Dir.mktmpdir("nibble-export"))
    [ dir, Nibble::Packages::Exporter.new(dir, **options).call ]
  end

  def read(dir, relative) = YAML.safe_load_file(dir.join(relative), permitted_classes: [ Date, Time ])

  setup { Nibble::Packages::Importer.new(DEMO).call }

  test "a record is written where its natural key says it lives" do
    dir, files = export

    assert_includes files, "collections/posts/en/grids.yml"
    assert_includes files, "collections/pages/en/about/team.yml", "a child sits under its parent"
    assert_includes files, "taxonomies/topics/en/design.yml"
    assert_includes files, "globals/site/en.yml"
    assert_includes files, "navigation/main/en.yml"
    assert_equal "Grids", read(dir, "collections/posts/en/grids.yml")["title"]
  end

  test "a Markdown field makes the round trip, with the asset it names carried as a path" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "photo.jpg")
    asset = Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:), :create, { "folder" => "site" }).record
    notes = "See ![desk](nibble://asset/#{asset.id}) for the layout."
    created = Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts"), :create,
      { "title" => "Round trip", "notes" => notes })
    assert created.ok?, created.errors.inspect

    dir, = export

    assert_equal "See ![desk](nibble://asset/site/photo.jpg) for the layout.", read(dir, "collections/posts/en/round-trip.yml")["notes"],
      "a package must name the asset by path, since an id means nothing on the site importing it"

    created.record.update_column(:data, created.record.data.merge("notes" => "replaced"))
    assert Nibble::Packages::Importer.new(dir, mode: "update").call.ok?

    assert_equal notes, Nibble::Records::Entry.find_by!(slug: "round-trip").values["notes"]
  end

  test "references come out as natural keys, not database ids" do
    dir, = export

    grids = read(dir, "collections/posts/en/grids.yml")
    assert_equal [ "topics/design" ], grids["topics"]
    assert_equal [ "posts/colour-theory" ], grids["related"]
    assert_equal "pages/about", read(dir, "navigation/main/en.yml")["tree"].first["entry"]
  end

  test "an entry keeps the columns an import needs to rebuild it" do
    dir, = export

    grids = read(dir, "collections/posts/en/grids.yml")
    assert_equal %w[blueprint status published_at], grids.keys.first(3)
    assert_equal "published", grids["status"]
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, grids["published_at"])
    assert_equal "draft", read(dir, "collections/posts/en/colour-theory.yml")["status"]
  end

  test "exporting twice writes the same bytes, so a package can live in git" do
    first, = export
    second, = export

    Dir.glob("**/*.yml", base: first).each do |relative|
      assert_equal first.join(relative).read, second.join(relative).read, relative
    end
  end

  test "filters narrow what comes out" do
    _, files = export(collections: %w[posts])

    assert(files.none? { |file| file.start_with?("collections/pages/") })
    assert(files.any? { |file| file.start_with?("collections/posts/") })

    _, published = export(status: "published")
    assert_not_includes published, "collections/posts/en/colour-theory.yml", "the draft stays behind"
  end

  test "redirects and asset metadata travel with the content" do
    dir, files = export

    assert_includes files, "redirects.yml"
    assert_equal "/blog/grids", read(dir, "redirects.yml").find { |row| row["from"] == "/old-grids" }["to"]
    assert_not_includes files, "assets.yml", "nothing to say about assets when the site has none"
  end

  test "workflow states export as draft, since a package only knows published and draft" do
    entry = Nibble::Records::Entry.find_by!(slug: "grids")
    entry.update_column(:status, "unpublished")
    dir, = export

    assert_equal "draft", read(dir, "collections/posts/en/grids.yml")["status"]
    assert Nibble::Packages::Importer.new(dir).validate.ok?, "what export writes, import accepts"
  end
end
