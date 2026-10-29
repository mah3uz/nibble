require "test_helper"

class Nibble::AssetsPurgeTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def old_asset(filename = "photo.jpg")
    create_asset({}, blob: upload_blob(filename)).tap { |asset| asset.update_columns(created_at: 3.days.ago) }
  end

  def unused = Nibble::Assets.unused(before: 1.day.ago).to_a
  def strays = Nibble::Assets.stray_blobs(before: 1.day.ago).to_a

  def command(*args)
    capture_io { Rails::Command.invoke("nibble:cleanup:assets", args) }.first
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

  test "the nightly purge deletes files apps sent but never used after a day, and nothing an asset holds" do
    grant = Nibble::Grant.create!(user: users(:editor), oauth_client: Nibble::OauthClient.cli, kind: "app", name: "App", preset: "everything",
      abilities: Nibble::AgentAccess.preset("everything"))
    stage = ->(name) { file_fixture("photo.jpg").open { |file| Nibble::Assets::Staged.store(file, filename: name, grant:) } }
    abandoned = stage.("abandoned.jpg")
    used = stage.("used.jpg").tap { |blob| create_asset({}, blob:) }
    stray = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "stray.jpg")
    travel 2.days
    fresh = stage.("fresh.jpg")

    Nibble::Jobs::PurgeTrash.perform_now

    assert_not ActiveStorage::Blob.exists?(abandoned.id)
    assert ActiveStorage::Blob.exists?(fresh.id), "an app may still use it"
    assert ActiveStorage::Blob.exists?(used.id), "a staged file an asset took is never purged, whatever its metadata says"
    assert ActiveStorage::Blob.exists?(stray.id), "other stray files are left to nibble:cleanup:assets"
  end
end
