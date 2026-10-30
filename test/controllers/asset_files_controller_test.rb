require "test_helper"

class AssetFilesControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  def image(body = response.body) = Vips::Image.new_from_buffer(body, "")

  test "the original file is served with a long public cache, and stale versions redirect to the current one" do
    asset = create_asset

    get asset.url
    assert_response :success
    assert_equal file_fixture("photo.jpg").binread, response.body
    assert_match "public", response.headers["Cache-Control"]

    get "/media/#{asset.uuid}/old-name.jpg?v=1"
    assert_redirected_to asset.url
  end

  test "only named presets transform, and only at the widths they list" do
    asset = create_asset

    get asset.url("card")
    assert_response :success
    assert_equal [ 32, 16 ], [ image.width, image.height ]

    get asset.url("card", width: 16)
    assert_equal [ 16, 8 ], [ image.width, image.height ]

    get asset.url("huge")
    assert_response :not_found
    get asset.url("card", width: 999)
    assert_response :not_found
  end

  test "a crop keeps the focal point in frame" do
    asset = create_asset
    asset.update_columns(width: 64, height: 32)
    square = { "w" => 16, "h" => 16, "fit" => "crop" }
    left = ->(focal_x) { asset.update_columns(focal_x:, focal_y: 0.5) && Nibble::Assets::Transform.transformations(asset, square)[:crop][0] }

    assert_equal [ 0, 8, 16 ], [ left.(0.0), left.(0.5), left.(1.0) ], "the 32px-wide scaled image slides its 16px window toward the focal point"
    asset.update_columns(focal_x: nil, focal_y: nil)
    assert_equal [ 8, 0, 16, 16 ], Nibble::Assets::Transform.transformations(asset, square)[:crop], "no focal point crops the centre"

    asset.update_columns(focal_x: 0.9, focal_y: 0.1)
    get asset.url("card")
    assert_equal [ 32, 16 ], [ image.width, image.height ], "libvips accepts the focal resize and crop"
  end

  test "focal zoom narrows every crop around the focal point, the way imgix's fp-z does" do
    asset = create_asset
    asset.update_columns(width: 64, height: 32, focal_x: 0.25, focal_y: 0.5)
    square = { "w" => 16, "h" => 16, "fit" => "crop" }

    assert_equal 0.5, Nibble::Assets::Transform.transformations(asset, square)[:resize]
    asset.update_columns(focal_zoom: 2)
    zoomed = Nibble::Assets::Transform.transformations(asset, square)
    assert_equal [ 1.0, [ 8, 8, 16, 16 ] ], zoomed.values_at(:resize, :crop), "twice the scale, window centred on the quarter point"
  end

  test "crop, rotation and flip apply before the preset, and the stored file stays untouched" do
    asset = create_asset
    asset.update_columns(width: 64, height: 32, edits: { "crop" => { "x" => 0.5, "y" => 0, "width" => 0.5, "height" => 1 }, "rotate" => 90, "flip" => "horizontal" })

    steps = Nibble::Assets::Transform.transformations(asset, Nibble::Assets.preset("cp-thumb"))
    assert_equal [ :rot, :flip, :extract_area, :resize_to_limit ], steps.keys.first(4), "the crop box is drawn on the turned image"
    assert_equal [ 16, 0, 16, 64 ], steps[:extract_area]
    assert_equal [ 16, 64 ], asset.edited_size

    get asset.url("card")
    assert_equal [ 32, 16 ], [ image.width, image.height ], "libvips runs the whole edit pipeline"
    get asset.url("cp-thumb")
    assert_equal [ 16, 64 ], [ image.width, image.height ], "thumbnails show the edited image"
    get asset.url
    assert_equal [ 16, 64 ], [ image.width, image.height ], "the plain URL shows the edited image too"
    assert_equal file_fixture("photo.jpg").binread, asset.blob.download
  end

  test "an edit reaches every use: the plain URL serves it at full size in the file's own format, and its value says so" do
    asset = create_asset
    asset.update_columns(width: 64, height: 32)
    lifecycle(asset, :save, "edits" => { "crop" => { "x" => 0.25, "y" => 0, "width" => 0.5, "height" => 1 } })
    asset.reload

    get asset.url
    assert_response :success
    assert_equal [ 32, 32 ], [ image.width, image.height ], "a field without a preset shows the crop, not the uncropped original"
    assert_equal "image/jpeg", response.media_type
    assert_match "public", response.headers["Cache-Control"]
    assert_equal [ 32, 32 ], Nibble::Records::AssetResolver.new.summary(asset).values_at("width", "height"), "the size a theme lays out matches the file"

    get asset.url("card")
    assert_equal [ 32, 16 ], [ image.width, image.height ], "a preset still fits its own box"
  end

  test "resetting the edits brings the original back on the plain URL, byte for byte" do
    asset = create_asset
    asset.update_columns(width: 64, height: 32)
    lifecycle(asset, :save, "edits" => { "rotate" => 90 })
    edited = asset.reload.url
    get edited
    assert_equal [ 32, 64 ], [ image.width, image.height ]

    lifecycle(asset, :save, "edits" => {})
    get edited
    assert_redirected_to asset.reload.url, "a page cached with the edited URL is sent to the current file"
    get asset.url
    assert_equal file_fixture("photo.jpg").binread, response.body
    assert_equal [ 64, 32 ], Nibble::Records::AssetResolver.new.summary(asset).values_at("width", "height")
  end

  test "an edited image moves off the address its original may be cached under, and an unedited one keeps its own" do
    asset = create_asset
    unedited = ->(edits) { "/media/#{asset.uuid}/photo.jpg?v=#{Digest::SHA256.hexdigest([ asset.blob_id, nil, nil, 1.0, edits ].to_json)[0, 12]}" }
    assert_equal unedited.({}), asset.url

    asset.update_columns(edits: { "rotate" => 90 })
    get unedited.({ "rotate" => 90 })
    assert_redirected_to asset.url
  end

  test "an edited PNG stays a PNG" do
    png = Vips::Image.black(4, 2, bands: 4).write_to_buffer(".png")
    asset = create_asset(blob: ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: "badge.png"))
    asset.update_columns(width: 4, height: 2, edits: { "rotate" => 90 })

    get asset.url
    assert_equal "image/png", response.media_type
    assert_equal [ 2, 4, 4 ], [ image.width, image.height, image.bands ], "turned, and its transparency survives"
  end

  test "files that aren't raster images ignore edits and are served as uploaded" do
    svg = %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><rect width="1" height="1"/></svg>)
    pdf = "%PDF-1.4\n%%EOF\n"
    [ [ svg, "logo.svg" ], [ pdf, "paper.pdf" ] ].each do |body, filename|
      asset = create_asset(blob: ActiveStorage::Blob.create_and_upload!(io: StringIO.new(body), filename:))
      asset.update_columns(edits: { "rotate" => 90 })

      get asset.url
      assert_response :success
      assert_equal body, response.body, filename
    end
  end

  test "any edit changes the URLs, so the forever cache never serves an old crop" do
    asset = create_asset
    before = asset.url("card")

    lifecycle(asset, :save, "focal_x" => 0.2, "focal_y" => 0.2)
    after_focal = asset.reload.url("card")
    lifecycle(asset, :save, "edits" => { "rotate" => 90 })

    assert_equal 3, [ before, after_focal, asset.reload.url("card") ].uniq.size
    get before
    assert_redirected_to asset.url("card")
  end

  test "browsers that accept WebP or AVIF get them, and caches keep one copy per format" do
    asset = create_asset

    get asset.url("card"), headers: { "Accept" => "image/avif,image/webp,*/*" }
    assert_equal "image/avif", response.media_type
    assert_equal "Accept", response.headers["Vary"]

    get asset.url("card"), headers: { "Accept" => "image/webp,*/*" }
    assert_equal "image/webp", response.media_type

    get asset.url("card"), headers: { "Accept" => "*/*" }
    assert_equal "image/jpeg", response.media_type
  end

  test "a transform is generated once and served from storage after that" do
    asset = create_asset
    get asset.url("card")
    first = response.body

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      get asset.url("card")
    end
    assert_equal first, response.body
  end

  test "transforms keep the photo's EXIF data" do
    asset = create_asset
    get asset.url("card")

    assert_match "Photographer", image.get("exif-ifd0-Artist")
  end

  test "files that can't be transformed only serve their original" do
    asset = create_asset({}, blob: upload_blob("pixel.png").tap { |blob| blob.update!(filename: "anim.gif") })

    get asset.url("card")
    assert_response :not_found
  end

  test "trashed assets and unknown ids are gone" do
    asset = create_asset
    lifecycle(asset, :trash)

    get asset.url
    assert_response :not_found
  end

  test "an SVG renders inline in an img tag but cannot run script when opened directly" do
    svg = %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><rect width="1" height="1"/></svg>)
    asset = create_asset(blob: ActiveStorage::Blob.create_and_upload!(io: StringIO.new(svg), filename: "logo.svg", content_type: "image/svg+xml"))

    get asset.url
    assert_response :success
    assert_equal "image/svg+xml", response.media_type
    assert_match(/\Ainline/, response.headers["Content-Disposition"])
    assert_match "sandbox", response.headers["Content-Security-Policy"]
    assert_equal svg, response.body
  end
end
