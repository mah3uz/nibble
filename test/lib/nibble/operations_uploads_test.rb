require "test_helper"
require "webmock"

class Nibble::OperationsUploadsTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  include ActiveJob::TestHelper
  include WebMock::API

  setup do
    Nibble::AgentAccess.update!(enabled: true, areas: { "assets" => { "read" => true, "write" => true } })
    roles(:editor).update!(abilities: roles(:editor).abilities + %w[apps.connect])
    @grant = grant_for
  end

  teardown do
    WebMock.reset!
    WebMock.disable!
  end

  def grant_for(kind: "ci") = Nibble::Grant.create!(user: users(:editor), oauth_client: Nibble::OauthClient.cli, kind:, name: "Test app",
    preset: "everything", abilities: Nibble::AgentAccess.preset("everything"))

  def run_op(name, input = {}, grant = @grant)
    principal = Nibble::Principal.new(user: grant.user, grant:)
    Nibble::Operations.call(name, input, caller: Nibble::Operations::Caller.new(principal:, site: "https://example.com", ip: "127.0.0.1"))
  end

  def failure(name, input = {}, grant = @grant)
    run_op(name, input, grant)
    flunk "#{name} should have failed"
  rescue Nibble::Operations::Failure => error
    error
  end

  def stage(name = "pixel.png", grant = @grant)
    blob = file_fixture(name).open { |file| Nibble::Assets::Staged.store(file, filename: name, grant:) }
    [ Nibble::Assets::Staged.id(blob), blob ]
  end

  test "exactly one source of the file is accepted" do
    id, = stage

    assert_equal "invalid_input", failure("upload_asset", "filename" => "a.png").code
    assert_equal "invalid_input", failure("upload_asset", "upload" => id, "content_base64" => Base64.strict_encode64("x"), "filename" => "a.png").code
    assert_equal "invalid_input", failure("upload_asset", "upload" => id, "url" => "https://example.test/a.png").code
  end

  test "a staged upload becomes an asset on its own stored file, once" do
    id, blob = stage

    assert_no_difference -> { ActiveStorage::Blob.count } do
      created = run_op("upload_asset", "upload" => id, "alt" => "A pixel")
      assert_equal [ "uploaded", "pixel.png", "A pixel" ], created.values_at("result", "filename", "alt")
      assert_equal blob.id, Nibble::Records::Asset.find(created["id"]).blob_id, "the file isn't stored a second time"
    end
    assert_not Nibble::Assets::Staged.staged?(blob.reload)
    assert_equal "upload_not_found", failure("upload_asset", "upload" => id).code, "an upload makes one asset"
  end

  test "another connection's upload is refused, even by the same person" do
    id, blob = stage

    assert_equal "upload_not_found", failure("upload_asset", { "upload" => id }, grant_for).code
    assert Nibble::Assets::Staged.staged?(blob.reload), "the owner can still use it"
  end

  test "an upload left longer than a day has expired" do
    id, = stage
    travel 1.day + 1.minute

    assert_equal "upload_not_found", failure("upload_asset", "upload" => id).code
  end

  test "an upload is not a blob id: a tampered or plain id is refused" do
    _, blob = stage

    assert_equal "upload_not_found", failure("upload_asset", "upload" => blob.signed_id).code
    assert_equal "upload_not_found", failure("upload_asset", "upload" => blob.id.to_s).code
  end

  test "an upload waiting for approval keeps only its id, and approving it uses the file already sent" do
    existing = create_asset({}, blob: upload_blob("pixel.png"))
    app = grant_for(kind: "app")
    id, blob = stage("pixel.png", app)

    asked = failure("upload_asset", { "upload" => id, "alt" => "Again" }, app)
    assert_equal "approval_required", asked.code
    approval = Nibble::Approval.find_by!(public_id: asked.details["approval"])
    assert_equal({ "upload" => id, "alt" => "Again" }, approval.input, "the approval holds the reference, not the file")

    perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
    assert ActiveStorage::Blob.exists?(blob.id), "asking for approval rehearses the upload, and the rehearsal mustn't take the file"
    assert Nibble::Assets::Staged.staged?(blob.reload)

    approval.update!(status: "approved")
    created = run_op("upload_asset", { "upload" => id, "alt" => "Again", "approval" => approval.public_id }, app)
    assert_equal existing.blob_id, Nibble::Records::Asset.find(created["id"]).blob_id, "the same file is stored once"
  end

  test "content_base64 still works, and needs a filename" do
    content = Base64.strict_encode64(file_fixture("pixel.png").binread)

    assert_equal "invalid_input", failure("upload_asset", "content_base64" => content).code
    assert_equal "uploaded", run_op("upload_asset", "content_base64" => content, "filename" => "pixel.png")["result"]
  end

  test "an upload keeps its own name" do
    id, = stage

    assert_equal "invalid_input", failure("upload_asset", "upload" => id, "filename" => "other.html").code
  end

  test "a url is fetched through the outbound guard, so private addresses are refused" do
    WebMock.enable!
    WebMock.disable_net_connect!
    resolver = Nibble::Outbound::Guard.resolver

    Nibble::Outbound::Guard.resolver = ->(_host) { [ "10.0.0.5" ] }
    refused = failure("upload_asset", "url" => "https://intranet.example.test/secret.png")
    assert_equal "fetch_failed", refused.code
    assert_match "private or reserved", refused.message
    assert_equal "fetch_failed", failure("upload_asset", "url" => "http://169.254.169.254/latest/meta-data.png").code

    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
    stub_request(:get, "https://cdn.example.test/images/pixel.png").to_return(status: 200, body: file_fixture("pixel.png").binread)
    created = run_op("upload_asset", "url" => "https://cdn.example.test/images/pixel.png")
    assert_equal [ "uploaded", "pixel.png" ], created.values_at("result", "filename")
    assert_equal "invalid", failure("upload_asset", "url" => "https://cdn.example.test/run.php").code, "the type is checked before fetching"
  ensure
    Nibble::Outbound::Guard.resolver = resolver
  end
end
