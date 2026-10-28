require "test_helper"
require Rails.root.join("vendor/nibble/db/migrate/20261029000000_nibble_pick_share_images_from_library")

class Nibble::ShareImageMigrationTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def migrate
    ActiveRecord::Migration.suppress_messages { NibblePickShareImagesFromLibrary.new.up }
  end

  def photo
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "photo.jpg")
    Nibble::Lifecycle.call(Nibble::Records::Asset.new(blob:), :create, actor: Nibble::Principal.system).record
  end

  test "a share image that points at a library asset becomes that asset, in the entry and its draft, and any other is removed" do
    asset = photo
    entry = publish_entry(create_entry("articles", { "title" => "One" }))
    entry.update_columns(data: entry.data.merge("seo" => { "title" => "T", "og_image" => "https://cdn.test#{asset.url('og')}" }))
    lifecycle(entry.reload, :save, { "title" => "Edited" })
    entry.draft.update_columns(data: entry.draft.data.merge("seo" => { "og_image" => "/media/#{asset.uuid}/photo.jpg" }))
    other = create_entry("articles", { "title" => "Two" })
    other.update_columns(data: other.data.merge("seo" => { "title" => "Keep", "og_image" => "https://elsewhere.test/a.png" }))

    migrate

    assert_equal({ "title" => "T", "og_image" => { "asset" => asset.id.to_s } }, entry.reload.data["seo"])
    assert_equal({ "asset" => asset.id.to_s }, entry.draft.reload.data.dig("seo", "og_image"))
    assert_equal({ "title" => "Keep" }, other.reload.data["seo"])
  end

  test "a site's own field that happens to be called og_image is not an SEO value, so it is left alone" do
    entry = create_entry("articles", { "title" => "Three" })
    entry.update_columns(data: entry.data.merge("og_image" => "https://elsewhere.test/b.png"))

    migrate

    assert_equal "https://elsewhere.test/b.png", entry.reload.data["og_image"]
  end

  test "running it again changes nothing" do
    asset = photo
    entry = create_entry("articles", { "title" => "One" })
    entry.update_columns(data: entry.data.merge("seo" => { "og_image" => "/media/#{asset.uuid}/photo.jpg" }))

    migrate
    once = entry.reload.data
    migrate

    assert_equal once, entry.reload.data
  end
end
