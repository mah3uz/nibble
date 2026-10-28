require "test_helper"

class Nibble::PackagesAssetsTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  def import(dir, **options) = Nibble::Packages::Importer.new(dir, **options).call
  def validate(dir) = Nibble::Packages::Importer.new(dir).validate
  def stored = Nibble::Records::Asset.count + ActiveStorage::Blob.count

  def package(files, assets: {})
    dir = Pathname(Dir.mktmpdir("nibble-package"))
    files.each do |path, content|
      dir.join(path).dirname.mkpath
      dir.join(path).write(content.is_a?(String) ? content : JSON.parse(content.to_json).to_yaml)
    end
    assets.each do |path, fixture|
      dir.join("assets", path).dirname.mkpath
      FileUtils.cp(file_fixture(fixture), dir.join("assets", path))
    end
    dir
  end

  def pictured(reference)
    { "collections/posts/en/pictured.yml" => { title: "Pictured", status: "draft",
      body: [ { type: "image", attrs: { asset: reference, alt: "A desk" } } ] } }
  end

  def logo(reference) = { "globals/site/en.yml" => { name: "Site", logo: reference } }

  def bundle(reference: "site/Team Photo (1).JPG")
    package(pictured(reference).merge("assets.yml" => [ { path: "site/Team Photo (1).JPG", mime: "image/jpeg", title: "Team", alt: "The team" } ]),
      assets: { "site/Team Photo (1).JPG" => "photo.jpg" })
  end

  test "a fresh database imports a package with its images in one command, and a reference in the original filename resolves" do
    dir = bundle

    assert validate(dir).ok?
    report = import(dir)

    assert report.ok?, report.errors.join("\n")
    asset = Nibble::Records::Asset.kept.find_by!(folder: "site")
    assert_equal [ "team-photo-1.jpg", "Team", "The team" ], [ asset.filename, asset.title, asset.alt ]
    assert_equal asset.id.to_s, Nibble::Records::Entry.find_by!(slug: "pictured").values["body"].first.dig("attrs", "asset")
    assert_includes report.created, "assets/site/Team Photo (1).JPG"
  end

  test "importing again creates nothing new" do
    dir = bundle
    import(dir)

    assert_no_difference -> { stored + Nibble::Records::Entry.count } do
      assert_empty import(dir).created
    end
  end

  test "a dry run lists the uploads and stores nothing" do
    dir = bundle

    assert_no_difference -> { stored } do
      report = Nibble::Packages::Importer.new(dir).preview
      assert report.ok?, report.errors.join("\n")
      assert_includes report.created, "assets/site/Team Photo (1).JPG"
    end
  end

  test "an asset the site already has is not uploaded again" do
    dir = bundle
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("pixel.png").open, filename: "team-photo-1.jpg")
    Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:, filename: "team-photo-1.jpg"), :create, { "folder" => "site" }, actor: Nibble::Principal.system)

    assert_no_difference -> { Nibble::Records::Asset.count } do
      assert_not_includes import(dir).created, "assets/site/Team Photo (1).JPG"
    end
  end

  test "a row whose file is missing still fails a reference to it" do
    dir = package(logo("site/ghost.jpg").merge("assets.yml" => [ { path: "site/ghost.jpg" } ]))

    assert_not validate(dir).ok?
  end

  test "a path that climbs out of the assets folder is never read" do
    dir = package(logo("../secret.jpg").merge("assets.yml" => [ { path: "../secret.jpg" } ]))
    dir.join("secret.jpg").write("x")

    assert_not validate(dir).ok?
    assert_no_difference -> { Nibble::Records::Asset.count } do
      import(dir)
    end
  end

  test "the Control Plane's unzip keeps asset files and still drops other binaries" do
    zip = Zip::OutputStream.write_buffer do |out|
      { "assets.yml" => "[]", "assets/site/a.jpg" => "jpg", "evil.exe" => "x" }.each do |name, content|
        out.put_next_entry(name)
        out.write(content)
      end
    end
    into = Pathname(Dir.mktmpdir("nibble-archive"))

    Nibble::Packages::Archive.extract(StringIO.new(zip.string), into:)

    assert_equal %w[assets.yml assets/site/a.jpg], Dir.glob("**/*", base: into).select { |path| into.join(path).file? }.sort
  end
end
