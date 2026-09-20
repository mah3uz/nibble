require "test_helper"

class Nibble::AssetsPurgeTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def old_asset(filename = "photo.jpg")
    create_asset({}, blob: upload_blob(filename)).tap { |asset| asset.update_columns(created_at: 3.days.ago) }
  end

  def unused = Nibble::Assets.unused(before: 1.day.ago).to_a
  def strays = Nibble::Assets.stray_blobs(before: 1.day.ago).to_a

  def command(*args)
    capture_io { Rails::Command.invoke("nibble:assets:purge_unused", args) }.first
  end

  test "an asset an entry uses is kept, and one nothing uses is listed" do
    used = old_asset
    spare = old_asset
    create_entry("articles", { "title" => "One", "image" => [ used.id.to_s ] })
    Nibble::Events.dispatch_pending

    assert_equal [ spare ], unused
  end

  test "an image only in a pending draft still counts as used, so a purge can't take an editor's work" do
    asset = old_asset
    article = publish_entry(create_entry("articles", { "title" => "Live" }))
    lifecycle(article.reload, :save, { "image" => [ asset.id.to_s ] })
    Nibble::Events.dispatch_pending

    assert article.reload.draft, "the change sits in a draft, not the live entry"
    assert_empty unused
  end

  test "an asset used only by a trashed entry is unused, as the asset screen says" do
    asset = old_asset
    article = create_entry("articles", { "title" => "Gone", "image" => [ asset.id.to_s ] })
    lifecycle(article, :trash)
    Nibble::Events.dispatch_pending

    assert_equal [ asset ], unused
  end

  test "anything uploaded inside the window is left alone, so an upload in progress isn't swept" do
    create_asset({}, blob: upload_blob("photo.jpg"))
    ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "fresh.jpg")

    assert_empty unused
    assert_empty strays
  end

  test "an asset's file is never stray, though no attachment points at it" do
    asset = old_asset
    trashed = old_asset.tap { |item| lifecycle(item, :trash) }
    stray = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "abandoned.jpg")
    [ asset.blob, trashed.blob, stray ].each { |blob| blob.update_columns(created_at: 3.days.ago) }

    assert_equal [ stray ], strays, "a trashed asset keeps its file until the trash lets it go"
  end

  test "without --confirm nothing changes; with it, assets go to the trash and stray files are deleted" do
    asset = old_asset
    stray = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "abandoned.jpg")
    stray.update_columns(created_at: 3.days.ago)

    assert_match "run with --confirm", command
    assert_not asset.reload.trashed?
    assert ActiveStorage::Blob.exists?(stray.id)

    output = command("--confirm")

    assert asset.reload.trashed?, "trashed, so it can still be restored"
    assert_not ActiveStorage::Blob.exists?(stray.id)
    assert_match "assets moved to the trash, files deleted", output
  end
end
