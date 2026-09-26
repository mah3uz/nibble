require "test_helper"

class Admin::DirectUploadsTest < ActionDispatch::IntegrationTest
  def request_upload(filename, byte_size: 10)
    post "/admin/direct_uploads", as: :json,
      params: { blob: { filename:, byte_size:, checksum: Digest::MD5.base64digest("x"), content_type: "application/octet-stream" } }
  end

  test "only signed-in users who can upload get an upload URL, so the bucket isn't open to the public" do
    request_upload("photo.jpg")
    assert_response :unauthorized

    sign_in_as users(:author)
    request_upload("photo.jpg")
    assert_response :success
    assert response.parsed_body.dig("direct_upload", "url")
  end

  test "Rails' own upload endpoint is closed, because it would hand an upload URL to anyone" do
    sign_in_as users(:author)

    assert_no_difference -> { ActiveStorage::Blob.count } do
      post "/rails/active_storage/direct_uploads", as: :json,
        params: { blob: { filename: "photo.jpg", byte_size: 10, checksum: Digest::MD5.base64digest("x"), content_type: "image/jpeg" } }
    end
    assert_response :not_found
  end

  test "a file the library won't accept is refused before anything is uploaded" do
    sign_in_as users(:editor)

    assert_no_difference -> { ActiveStorage::Blob.count } do
      request_upload("shell.php")
    end
    assert_response :unprocessable_entity
    assert_match ".php", response.parsed_body["error"]
  end
end
