require "test_helper"

class Nibble::Cp::MediaControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  Asset = Nibble::Records::Asset

  setup { sign_in_as users(:editor) }

  def json(method, path, params = {}) = public_send(method, path, params:, as: :json).then { response.body.present? ? response.parsed_body : {} }

  test "the library lists the current folder's assets and subfolders, and searching looks everywhere" do
    create_asset({ "folder" => "team" })
    root = create_asset
    Nibble::Records::AssetFolder.ensure!("team/2026")

    body = json(:get, "/cp/media")
    assert_equal [ root.id ], body["listing"]["rows"].map { |row| row["id"] }
    assert_equal [ "team" ], body["folders"].map { |folder| folder["path"] }
    assert_equal [ "team/2026" ], json(:get, "/cp/media?folder=team")["folders"].map { |folder| folder["path"] }
    assert_equal 2, json(:get, "/cp/media?q=photo")["listing"]["rows"].size
  end

  test "the page size is always one the per-page menu offers, so the menu never shows blank" do
    pagination = json(:get, "/cp/media")["listing"]["pagination"]
    assert_includes pagination["per_page_options"], pagination["per_page"]

    pagination = json(:get, "/cp/media?per_page=7")["listing"]["pagination"]
    assert_includes pagination["per_page_options"], pagination["per_page"], "a page size the menu doesn't offer falls back"
  end

  test "the unused filter is the unused-asset report, and it leaves out anything content still uses" do
    used = create_asset
    unused = create_asset({}, blob: upload_blob("pixel.png"))
    create_entry("articles", { "image" => { "asset" => used.id.to_s } })

    assert_equal [ unused.id ], json(:get, "/cp/media?usage=unused")["listing"]["rows"].map { |row| row["id"] }
    assert_equal [ used.id ], json(:get, "/cp/media?usage=used")["listing"]["rows"].map { |row| row["id"] }
  end

  test "an upload becomes an asset in the folder it was dropped into" do
    blob = upload_blob

    body = json(:post, "/cp/media", { signed_id: blob.signed_id, folder: "photos" })
    assert_response :created
    assert_equal [ "photos", "photo.jpg" ], Asset.find(body["asset"]["id"]).values_at(:folder, :filename)
  end

  test "renaming keeps the extension, so a file can't be renamed into another type" do
    asset = create_asset

    json(:patch, "/cp/media/#{asset.id}", { asset: { filename: "Holiday Snap.php" } })
    assert_equal "holiday-snap.jpg", asset.reload.filename
  end

  test "reupload swaps the file behind the same asset, so every reference and URL follows it" do
    asset = create_asset
    entry = create_entry("articles", { "image" => { "asset" => asset.id.to_s } })
    old_url = asset.url
    blob = upload_blob("pixel.png")

    json(:post, "/cp/media/#{asset.id}/reupload", { signed_id: blob.signed_id })
    asset.reload
    assert_equal [ blob.id, "photo.png" ], [ asset.blob_id, asset.filename ]
    assert_not_equal old_url, asset.url
    assert_equal asset.id.to_s, entry.reload.data.dig("image", "asset")

    get old_url
    assert_redirected_to asset.url
  end

  test "replace points every use at another asset, live and in drafts, and can trash the original" do
    old = create_asset
    fresh = create_asset({}, blob: upload_blob("pixel.png"))
    live = publish_entry(create_entry("articles", { "image" => { "asset" => old.id.to_s, "alt" => "Kept" } }))
    lifecycle(live.reload, :save, "summary" => "Draft note")

    body = json(:post, "/cp/media/#{old.id}/replace", { with: fresh.id, delete_original: true })
    assert_equal 1, body["replaced"]
    live.reload
    assert_equal({ "asset" => fresh.id.to_s, "alt" => "Kept" }, live.data["image"])
    assert_equal fresh.id.to_s, live.draft.data.dig("image", "asset")
    assert old.reload.trashed?
  end

  test "a replace that can't reach every use says where, and keeps the original, so nothing is left pointing at the trash" do
    old = create_asset
    fresh = create_asset({}, blob: upload_blob("pixel.png"))
    create_entry("articles", { "title" => "Kept back", "image" => { "asset" => old.id.to_s } })
    create_entry("articles", { "title" => "Changed", "image" => { "asset" => old.id.to_s } })
    Nibble::Lifecycle.guard(:replace_asset) { |record| "it's being reviewed" if record.title == "Kept back" }

    body = json(:post, "/cp/media/#{old.id}/replace", { with: fresh.id, delete_original: true })

    assert_response :unprocessable_entity
    assert_equal 1, body["replaced"]
    assert_match "Kept back", body["error"], "the editor shows this message, so it has to name what failed"
    assert_not old.reload.trashed?
  ensure
    Nibble::Lifecycle.reset_guards!
  end

  test "bulk actions move, tag, duplicate and trash many assets at once" do
    one = create_asset
    two = create_asset({}, blob: upload_blob("pixel.png"))
    ids = [ one.id, two.id ]

    json(:post, "/cp/media/bulk", { handle: "move", ids:, folder: "archive" })
    json(:post, "/cp/media/bulk", { handle: "tag", ids:, tag: "2026" })
    assert_equal [ [ "archive", [ "2026" ] ] ] * 2, Asset.where(id: ids).map { |asset| [ asset.folder, asset.tags ] }

    assert_difference -> { Asset.count }, 2 do
      json(:post, "/cp/media/bulk", { handle: "duplicate", ids: })
    end
    json(:post, "/cp/media/bulk", { handle: "trash", ids: })
    assert Asset.where(id: ids).all?(&:trashed?)
  end

  test "save as copy makes a new asset with the edits, sharing the stored file" do
    asset = create_asset({ "alt" => "Sunset" })

    body = json(:post, "/cp/media/#{asset.id}/duplicate", { asset: { edits: { rotate: 180 } } })
    copy = Asset.find(body["asset"]["id"])
    assert_equal [ asset.blob_id, "Sunset", { "rotate" => 180 }, {} ], [ copy.blob_id, copy.alt, copy.edits, asset.reload.edits ]
  end

  test "deleting an asset in use asks first and names where it's used" do
    asset = create_asset
    create_entry("articles", { "title" => "Holiday", "image" => { "asset" => asset.id.to_s } })

    body = json(:delete, "/cp/media/#{asset.id}")
    assert_response :conflict
    assert_equal [ "Holiday" ], body["referrers"].map { |item| item["title"] }

    json(:delete, "/cp/media/#{asset.id}?force=true")
    assert asset.reload.trashed?
  end

  test "folders are created, renamed with everything inside, and only deleted when empty" do
    json(:post, "/cp/media/folders", { parent: "", name: "Team Photos" })
    asset = create_asset({ "folder" => "team-photos/2026" })

    json(:patch, "/cp/media/folders", { path: "team-photos", name: "people" })
    assert_equal "people/2026", asset.reload.folder
    assert_equal %w[people people/2026], Nibble::Records::AssetFolder.order(:path).pluck(:path)

    json(:delete, "/cp/media/folders?path=people")
    assert_response :unprocessable_entity
    lifecycle(asset, :trash)
    asset.destroy!
    json(:delete, "/cp/media/folders?path=people")
    assert_empty Nibble::Records::AssetFolder.all
  end

  test "authors can upload but can't edit or delete assets" do
    sign_in_as users(:author)
    asset = create_asset

    json(:post, "/cp/media", { signed_id: upload_blob.signed_id })
    assert_response :created
    json(:patch, "/cp/media/#{asset.id}", { asset: { alt: "x" } })
    assert_response :forbidden
    json(:post, "/cp/media/bulk", { handle: "trash", ids: [ asset.id ] })
    assert_response :forbidden
  end

  test "the editor gets the asset's fields, usage and folders" do
    asset = create_asset({ "alt" => "Sunset" })
    create_entry("articles", { "title" => "Holiday", "image" => { "asset" => asset.id.to_s } })

    body = json(:get, "/cp/media/#{asset.id}")
    assert_equal "Sunset", body["values"]["alt"]
    assert_equal [ [ "Holiday", "image" ] ], body["usage"].map { |use| use.values_at("title", "field") }
    assert_equal "Root", body["folder_options"].first["label"]
  end

  test "trashed assets show in the trash, restore from it, and purging deletes the file" do
    asset = create_asset
    lifecycle(asset, :trash)

    get "/cp/trash"
    assert_includes Nokogiri::HTML(response.body).at_css("script[data-page]").text, "asset-#{asset.id}"

    post "/cp/trash/asset-#{asset.id}/restore"
    assert_not asset.reload.trashed?
    lifecycle(asset, :trash)
    assert_enqueued_with(job: ActiveStorage::PurgeJob) { delete "/cp/trash/asset-#{asset.id}/purge" }
    assert_not Asset.exists?(asset.id)
  end

  test "the assets field preloads the stored assets, so the editor shows them after a reload" do
    asset = create_asset
    field = Nibble::Records::Entry.new(collection: "articles", blueprint: "article").blueprint_fields.get("image")

    preload = field.with_value({ "asset" => asset.id.to_s, "alt" => nil }).fieldtype.preload
    assert_equal [ asset.id.to_s ], preload["data"].map { |item| item["id"] }
  end
end
