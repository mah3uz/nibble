require "test_helper"

class Api::UploadsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup do
    Nibble::AgentAccess.update!(enabled: true, areas: { "assets" => { "read" => true, "write" => true } })
    roles(:editor).update!(abilities: roles(:editor).abilities + %w[apps.connect])
    @grant = grant
    @token = Nibble::OauthToken.issue(@grant, "access", resource: "https://example.com/api/v1")
  end

  def grant(preset = "everything", user: users(:editor)) = Nibble::Grant.create!(user:, oauth_client: Nibble::OauthClient.cli, kind: "app",
    name: "Nibble CLI", preset:, abilities: Nibble::AgentAccess.preset(preset))

  def json = JSON.parse(response.body)
  def pixel = file_fixture("pixel.png").binread

  def send_file(path, body = pixel, token: @token, type: "application/octet-stream")
    headers = { "Content-Type" => type }
    headers["Authorization"] = "Bearer #{token}" if token
    put path, params: body, headers:
  end

  test "a file sent with the API's token is held for this connection only, with no asset and no address" do
    assert_no_difference -> { Nibble::Records::Asset.count } do
      send_file "/api/v1/uploads?filename=pixel.png"
    end

    assert_response :created
    blob = Nibble::Assets::Staged.find(json.dig("data", "upload"), @grant)
    assert_equal [ "pixel.png", pixel.bytesize ], [ blob.filename.to_s, blob.byte_size ]
    assert_nil Nibble::Assets::Staged.find(json.dig("data", "upload"), grant), "another connection can't use it"
    assert_equal (blob.created_at + 1.day).utc.iso8601, json.dig("data", "expires_at")
    assert_equal "https://example.com", json.dig("meta", "site")

    get "/rails/active_storage/blobs/redirect/#{json.dig('data', 'upload')}/pixel.png"
    assert_response :not_found, "the upload id isn't a key to Rails' own file addresses"
  end

  test "the body is taken as the file whatever Content-Type it's sent with, as curl's --data-binary sends a form type" do
    body = "#{pixel}&a=%zz"
    send_file "/api/v1/uploads?filename=pixel.png", body, type: "application/x-www-form-urlencoded"

    assert_response :created
    assert_equal body.bytesize, Nibble::Assets::Staged.find(json.dig("data", "upload"), @grant).byte_size
  end

  test "the type and size are checked before anything is stored" do
    Nibble.config = Nibble::Config.new({ "theme" => "records", "url" => "https://example.com", "assets" => { "max_upload_mb" => 1 } },
      themes_path: @nibble_themes, site_schema_path: @nibble_themes.join("site_schema"))

    assert_no_difference -> { ActiveStorage::Blob.count } do
      send_file "/api/v1/uploads?filename=shell.php", "<?php"
      assert_response :unsupported_media_type
      assert_equal "unsupported_type", json["code"]

      send_file "/api/v1/uploads?filename=pixel.png", "a" * (1.megabyte + 1)
      assert_response :content_too_large
      assert_equal "too_large", json["code"]

      send_file "/api/v1/uploads?filename=pixel.png", ""
      assert_response :bad_request
    end
  end

  test "sending files needs the upload permission, through the app's grant" do
    @token = Nibble::OauthToken.issue(grant("draft"), "access", resource: "https://example.com/api/v1")

    assert_no_difference -> { ActiveStorage::Blob.count } do
      send_file "/api/v1/uploads?filename=pixel.png"
    end
    assert_response :forbidden
  end

  test "without a token, or with one in the URL, nothing is accepted" do
    send_file "/api/v1/uploads?filename=pixel.png", token: nil
    assert_response :unauthorized

    send_file "/api/v1/uploads?filename=pixel.png&access_token=#{@token}", token: nil
    assert_response :bad_request
  end

  test "create_upload's URL takes one file without the token, for this connection, and stops working after a while" do
    post "/api/v1/operations/create_upload", params: { filename: "pixel.png" }, headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    assert_response :success
    answer = json["data"]
    assert_equal [ "PUT", 15.minutes.to_i ], answer.values_at("method", "expires_in")
    assert_includes answer["accepted_types"], "png"
    url = URI(answer["url"])
    assert_equal "/api/v1/uploads", url.path

    send_file url.request_uri, token: nil
    assert_response :created
    assert Nibble::Assets::Staged.find(json.dig("data", "upload"), @grant)

    travel 16.minutes
    send_file url.request_uri, token: nil
    assert_response :unauthorized
  end

  test "an upload URL's token never reaches the log, as anyone holding it could send files as the app" do
    post "/api/v1/operations/create_upload", params: { filename: "pixel.png" }, headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    url = URI(json.dig("data", "url"))
    token = Rack::Utils.parse_query(url.query)["upload_token"]
    log = StringIO.new
    Rails.logger.broadcast_to(ActiveSupport::Logger.new(log))

    send_file url.request_uri, token: nil
    assert_response :created
    assert_match "upload_token=[FILTERED]", log.string
    assert_no_match token, log.string
  ensure
    Rails.logger.broadcasts.pop if log
  end

  test "an upload URL stops working once its app is disconnected" do
    post "/api/v1/operations/create_upload", params: { filename: "pixel.png" }, headers: { "Authorization" => "Bearer #{@token}" }, as: :json
    url = URI(json.dig("data", "url"))
    @grant.revoke!

    send_file url.request_uri, token: nil
    assert_response :unauthorized
  end

  test "create_upload refuses a file type the site won't take before anything is sent" do
    post "/api/v1/operations/create_upload", params: { filename: "shell.php" }, headers: { "Authorization" => "Bearer #{@token}" }, as: :json

    assert_response :unprocessable_content
    assert_match ".php", json["detail"]
  end

  test "a staged image's thumbnail is shown only to the person whose app sent it, and only if it really is an image" do
    send_file "/api/v1/uploads?filename=pixel.png"
    image = json.dig("data", "upload")
    send_file "/api/v1/uploads?filename=fake.png", "<html><script>alert(1)</script></html>"
    fake = json.dig("data", "upload")

    sign_in_as users(:admin)
    get "/cp/uploads/#{image}/preview"
    assert_response :not_found

    sign_in_as users(:editor)
    get "/cp/uploads/#{image}/preview"
    assert_response :success
    assert_equal "image/png", response.media_type

    get "/cp/uploads/#{fake}/preview"
    assert_response :unprocessable_content
  end
end
