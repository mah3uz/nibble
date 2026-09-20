require "test_helper"

class Nibble::PackagesUpdateTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  DEMO = Rails.root.join("test/nibble_packages/demo")

  def import(dir = DEMO, **options) = Nibble::Packages::Importer.new(dir, **options).call
  def entry(slug) = Nibble::Records::Entry.find_by!(slug:)

  def package(files)
    dir = Pathname(Dir.mktmpdir("nibble-package"))
    files.each do |path, content|
      dir.join(path).dirname.mkpath
      dir.join(path).write(content.is_a?(String) ? content : JSON.parse(content.to_json).to_yaml)
    end
    dir
  end

  setup { import }

  def create_asset(title: nil)
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "photo.jpg")
    result = Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:), :create, { "title" => title }.compact)
    assert result.ok?, "asset create failed: #{result.errors}"
    result.record
  end

  test "update mode changes what the package says and leaves everything else alone" do
    other = entry("colour-theory")
    changed = package("collections/posts/en/grids.yml" => { title: "Grids, again", published_at: "2026-01-02T09:00:00Z",
                                                            excerpt: "A new excerpt.", topics: [ "topics/design" ] })

    report = import(changed, mode: "update")

    assert report.ok?, report.errors.join("\n")
    assert_equal [ "collections/posts/en/grids.yml" ], report.updated
    assert_equal [ "Grids, again", "A new excerpt." ], entry("grids").values.values_at("title", "excerpt")
    assert_equal "published", entry("grids").status, "a live entry stays live with the new content"
    assert Nibble::Records::Entry.exists?(other.id), "update never deletes what the package doesn't mention"
  end

  test "create mode leaves an existing record exactly as it was" do
    changed = package("collections/posts/en/grids.yml" => { title: "Should not land", published_at: "2026-01-02T09:00:00Z" })

    report = import(changed)

    assert_equal [ "collections/posts/en/grids.yml" ], report.skipped
    assert_equal "Grids", entry("grids").title
  end

  test "running the same update twice changes nothing the second time" do
    changed = package("collections/posts/en/grids.yml" => { title: "Grids, again", published_at: "2026-01-02T09:00:00Z" })
    import(changed, mode: "update")
    revisions = entry("grids").revisions.count

    import(changed, mode: "update")

    assert_equal revisions, entry("grids").revisions.count
  end

  test "globals, navigation and redirects are refreshed in update mode" do
    changed = package(
      "globals/site/en.yml" => { name: "Renamed site" },
      "redirects.yml" => [ { from: "/old-grids", to: "/blog/grids-moved" } ]
    )

    report = import(changed, mode: "update")

    assert report.ok?, report.errors.join("\n")
    assert_equal "Renamed site", Nibble::Records::GlobalSet.find_by!(handle: "site").data["name"]
    assert_equal "/blog/grids-moved", Nibble::Records::Redirect.find_by!(from: "/old-grids").to
  end

  test "asset metadata is applied to assets that are already here, and a missing one is only noted" do
    create_asset(title: "Before")
    changed = package("assets.yml" => [ { path: "photo.jpg", title: "After", alt: "A photo" },
                                        { path: "missing/nowhere.jpg", title: "Ghost" } ])

    report = import(changed, mode: "update")

    assert report.ok?, report.errors.join("\n")
    asset = Nibble::Records::Asset.find_by!(filename: "photo.jpg")
    assert_equal [ "After", "A photo" ], [ asset.title, asset.alt ]
    assert_includes report.skipped, "assets.yml: missing/nowhere.jpg"
  end

  test "an asset is referenced by its path, as export writes it" do
    asset = create_asset
    references = Nibble::Packages::References.new([])
    context = Nibble::Packages::Context.new(references, "en", strict: true)

    assert_equal asset.id.to_s, context.resolve("asset", "photo.jpg")
    assert_raises(Nibble::Error) { context.resolve("asset", "nowhere/missing.jpg") }
  end

  test "an import tells cache and search, but not webhooks, unless asked" do
    webhook = Nibble::Records::Webhook.create!(name: "Hook", url: "https://hooks.example.test", events: [ "record.*" ],
      secret_ciphertext: Nibble::Secrets.encrypt("whsec_x"))
    changed = package("collections/posts/en/grids.yml" => { title: "Quiet", published_at: "2026-01-02T09:00:00Z" })

    import(changed, mode: "update")
    Nibble::Events.dispatch_pending
    assert_equal 0, webhook.deliveries.count

    loud = package("collections/posts/en/grids.yml" => { title: "Loud", published_at: "2026-01-02T09:00:00Z" })
    import(loud, mode: "update", notify: true)
    Nibble::Events.dispatch_pending
    assert_operator webhook.deliveries.count, :>, 0
  end
end
