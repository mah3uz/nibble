require "test_helper"

class Nibble::AssetsTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  Asset = Nibble::Records::Asset

  def resolver = Nibble::Resolvers.find("asset")

  test "an assets field accepts only real, kept assets and records the relation for usage" do
    asset = create_asset({ "alt" => "Orange" })
    entry = create_entry("articles", { "image" => { "asset" => asset.id.to_s, "alt" => "" } })

    assert_equal [ [ "image", "asset", asset.id ] ], Nibble::Records::Relation.where(source_type: "entry", source_id: entry.id).pluck(:field, :target_type, :target_id)
    assert lifecycle(Nibble::Records::Entry.new(collection: "articles"), :create, "title" => "x", "image" => { "asset" => "0" }).invalid?

    lifecycle(asset, :trash, "force" => true)
    assert lifecycle(entry.reload, :save, "image" => { "asset" => asset.id.to_s }).invalid?, "a trashed asset can't be picked"
  end

  test "themes get the field's preset URL, a srcset from its widths, and the asset's alt unless the use overrides it" do
    asset = create_asset({ "alt" => "Orange", "focal_x" => 0.2, "focal_y" => 0.8 })
    field = Nibble::Records::Entry.new(collection: "articles", blueprint: "article").blueprint_fields.get("image")

    value = field.fieldtype.augment({ "asset" => asset.id.to_s, "alt" => nil })
    assert_equal "/media/#{asset.uuid}/card/photo.jpg?v=#{asset.version}", value["url"]
    assert_equal "/media/#{asset.uuid}/card/photo.jpg?v=#{asset.version}&w=16 16w, /media/#{asset.uuid}/card/photo.jpg?v=#{asset.version}&w=32 32w", value["srcset"]
    assert_equal [ "Orange", { "x" => 0.2, "y" => 0.8 } ], value.values_at("alt", "focal")
    assert_equal "Per use", field.fieldtype.augment({ "asset" => asset.id.to_s, "alt" => "Per use" })["alt"]
  end

  test "a restricted field only finds assets in its folder and subfolders, with the allowed types" do
    inside = create_asset({ "folder" => "team/2026" })
    create_asset({ "folder" => "teams" })
    logo = create_asset({ "folder" => "team" }, blob: upload_blob("pixel.png"))

    assert_equal [ logo.id.to_s, inside.id.to_s ].sort, resolver.search(query: "", scope: { "folder" => [ "team" ] }).map { |item| item["id"] }.sort
    assert_equal [ logo.id.to_s ], resolver.search(query: "pix", scope: { "folder" => [ "team" ], "allowed_types" => [ "png" ] }).map { |item| item["id"] }
  end

  test "uploads outside the allowlist or over the size limit are refused and their blob discarded" do
    script = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("<?php"), filename: "shell.php")
    result = Nibble::Assets::Upload.call(script)
    assert result.invalid?
    assert_match ".php", result.errors["file"].first
    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [ script ])

    assert_match "larger than 50 MB", Nibble::Assets::Upload.refusal("big.mp4", 51.megabytes)
    assert_nil Nibble::Assets::Upload.refusal("Report.PDF", 1)
  end

  test "an upload gets a clean filename and its kind from the extension" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "Summer Trip (1).JPG")
    asset = Nibble::Assets::Upload.call(blob).record

    assert_equal [ "summer-trip-1.jpg", "image" ], [ asset.filename, asset.kind ]
    assert_equal "video", Nibble::Assets.kind_for("clip.MOV")
    assert_equal "file", Nibble::Assets.kind_for("notes.docx")
  end

  test "the same file uploaded twice becomes two assets sharing one stored blob" do
    first = Nibble::Assets::Upload.call(upload_blob).record
    second = Nibble::Assets::Upload.call(upload_blob).record

    third = Nibble::Assets::Upload.call(upload_blob.tap { |blob| blob.update!(filename: "copy.jpg") }).record

    assert_not_equal first.id, second.id
    assert_equal [ first.blob_id ] * 2, [ second.blob_id, third.blob_id ]
    assert_equal "copy.jpg", third.filename, "each upload keeps the name it was uploaded with"
  end

  test "SVGs lose scripts, event handlers and external references before they're stored" do
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" onload="alert(1)" viewBox="0 0 10 10">
        <script>alert(2)</script>
        <a href="javascript:alert(3)"><rect width="10" height="10"/></a>
        <use xlink:href="#shape"/>
        <foreignObject><iframe src="https://evil.test"/></foreignObject>
      </svg>
    SVG
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(svg), filename: "logo.svg", content_type: "image/svg+xml")
    stored = Nibble::Assets::Upload.call(blob).record.blob.download

    %w[onload script javascript: foreignObject iframe].each { |unsafe| assert_not_includes stored, unsafe }
    assert_includes stored, %(xlink:href="#shape"), "internal references still work"
    assert_includes stored, "<rect"
  end

  test "file facts arrive after upload once the file is analyzed" do
    asset = Nibble::Assets::Upload.call(upload_blob).record
    assert_nil asset.width

    perform_enqueued_jobs(only: Nibble::Jobs::AnalyzeAsset)
    assert_equal [ 64, 32 ], asset.reload.values_at(:width, :height)
    assert_equal 0, asset.lock_version, "analysis doesn't conflict with an editor that's already open"
  end
end
