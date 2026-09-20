require "test_helper"

class Nibble::LifecycleAssetsTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  Asset = Nibble::Records::Asset

  def upload(name = "pixel.png", metadata: { "width" => 1, "height" => 1, "analyzed" => true }) = upload_blob(name, metadata:)

  test "an asset takes its file facts from the blob, so the library never disagrees with storage" do
    asset = create_asset({ "title" => "Pixel", "alt" => "A single dot" }, blob: upload)

    assert_equal [ "pixel.png", "image/png", file_fixture("pixel.png").size, 1, 1 ], [ asset.filename, asset.mime, asset.size, asset.width, asset.height ]
    assert_equal({ "title" => "Pixel", "alt" => "A single dot", "caption" => nil, "credit" => nil }, asset.values)
    assert_equal %w[record.created], Nibble::Records::OutboxEvent.pluck(:name)
    assert_empty asset.revisions, "asset edits are audited, not revisioned"
  end

  test "fields a layer adds to the asset blueprint land in data, beside the metadata columns" do
    asset = create_asset
    assert lifecycle(asset, :save, "caption" => "Sunrise", "license" => "cc0", "tags" => [ " sky ", "sky", "" ], "focal_x" => 0.25, "focal_y" => 0.75).ok?

    asset.reload
    assert_equal [ "Sunrise", [ "sky" ], { "x" => 0.25, "y" => 0.75 } ], [ asset.caption, asset.tags, asset.focal ]
    assert_equal({ "license" => "cc0" }, asset.data)
    assert lifecycle(asset, :save, "license" => "stolen").invalid?
  end

  test "a focal point needs both coordinates inside the image" do
    asset = create_asset
    assert lifecycle(asset, :save, "focal_x" => 0.5).invalid?
    assert lifecycle(asset.reload, :save, "focal_x" => 1.5, "focal_y" => 0.5).invalid?
  end

  test "edits stay inside the image and a full-image crop or no rotation is stored as no edit at all" do
    asset = create_asset

    assert lifecycle(asset, :save, "edits" => { "crop" => { "x" => 0, "y" => 0, "width" => 1, "height" => 1 }, "rotate" => 360 }).ok?
    assert_equal({}, asset.reload.edits)
    assert lifecycle(asset, :save, "edits" => { "crop" => { "x" => 0.6, "y" => 0, "width" => 0.6, "height" => 1 } }).invalid?
    assert lifecycle(asset.reload, :save, "edits" => { "rotate" => 45 }).invalid?
    assert lifecycle(asset.reload, :save, "focal_zoom" => 11).invalid?
  end

  test "a reupload clears the crop and zoom, because they described the old image" do
    asset = create_asset({ "edits" => { "rotate" => 90 }, "focal_zoom" => 3 })
    assert Nibble::Assets::Upload.replace(asset, upload_blob("pixel.png")).ok?

    assert_equal [ {}, 1.0 ], asset.reload.values_at(:edits, :focal_zoom)
  end

  test "a reupload may change format but not kind, so fields expecting an image keep getting one" do
    asset = create_asset
    svg = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(%(<svg xmlns="http://www.w3.org/2000/svg"/>)), filename: "logo.svg", content_type: "image/svg+xml")
    assert Nibble::Assets::Upload.replace(asset, svg).ok?
    assert Nibble::Assets::Upload.replace(asset.reload, upload_blob("pixel.png")).ok?
    assert_equal "photo.png", asset.reload.filename

    result = Nibble::Assets::Upload.replace(asset, ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4"), filename: "doc.pdf"))
    assert result.invalid?
    assert_equal [ "Reupload an image to replace an image." ], result.errors["file"]
    assert_equal "photo.png", asset.reload.filename
  end

  test "saving into a nested folder creates the folders on the way" do
    asset = create_asset({ "folder" => "/photos/2026/" })

    assert_equal "photos/2026", asset.folder
    assert_equal({ "photos" => nil, "photos/2026" => "photos" },
      Nibble::Records::AssetFolder.includes(:parent).to_h { |folder| [ folder.path, folder.parent&.path ] })
    assert lifecycle(asset, :save, "folder" => "Photos/../x").invalid?
  end

  test "trashing an asset used by content asks first, and restore brings it back" do
    asset = create_asset
    entry = create_entry("articles")
    Nibble::Records::Relation.create!(source: entry, field: "image", locale: "en", target_type: "asset", target_id: asset.id, position: 0)

    assert lifecycle(asset, :trash).needs_confirmation?
    assert lifecycle(asset, :trash, "force" => true).ok?
    assert lifecycle(asset, :save, "alt" => "x").invalid?, "trashed assets can't be edited"
    assert lifecycle(asset.reload, :restore).ok?
    assert_nil asset.reload.deleted_at
  end

  test "purging expired trash deletes a blob only once no other asset shares it" do
    shared = upload
    kept = create_asset({}, blob: shared)
    expired = create_asset({}, blob: shared)
    alone = create_asset({}, blob: upload)
    [ expired, alone ].each { |asset| asset.update_columns(deleted_at: 60.days.ago) }

    assert_enqueued_jobs(1, only: ActiveStorage::PurgeJob) { Nibble::Jobs::PurgeTrash.perform_now }
    assert_equal [ kept.id ], Asset.pluck(:id)
    assert ActiveStorage::Blob.exists?(shared.id)
  end
end
