require "test_helper"

class Api::V2Test < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup do
    Nibble::AgentAccess.update!(enabled: true)
    roles(:editor).update!(abilities: roles(:editor).abilities + %w[apps.connect])
    @grant = Nibble::Grant.create!(user: users(:editor), oauth_client: Nibble::OauthClient.cli, kind: "app", name: "Nibble CLI",
      preset: "draft", abilities: Nibble::AgentAccess.preset("draft"))
    @token = Nibble::OauthToken.issue(@grant, "access", resource: "https://example.com/api/v2")
  end

  def headers(token = @token) = { "Authorization" => "Bearer #{token}" }
  def json = JSON.parse(response.body)

  test "without a token the API says where to sign in" do
    get "/api/v2/whoami"

    assert_response :unauthorized
    assert_match 'resource_metadata="https://example.com/.well-known/oauth-protected-resource/api/v2"', response.headers["WWW-Authenticate"]
    assert_equal "application/problem+json", response.media_type
  end

  test "a token meant for the MCP endpoint doesn't open the API" do
    mcp = Nibble::OauthToken.issue(@grant, "access", resource: "https://example.com/mcp")

    get "/api/v2/whoami", headers: headers(mcp)
    assert_response :unauthorized
  end

  test "a token in the URL is refused, because URLs end up in logs" do
    get "/api/v2/whoami", params: { access_token: @token }

    assert_response :bad_request
  end

  test "an app reads and writes as its person, and every answer says which site it came from" do
    get "/api/v2/whoami", headers: headers
    assert_equal users(:editor).email_address, json.dig("data", "person", "email")
    assert_equal "https://example.com", json.dig("meta", "site")

    post "/api/v2/create_entry", params: { collection: "articles", data: { title: "Over HTTP" } }, headers:, as: :json
    assert_response :success
    assert_equal "draft", json.dig("data", "status")
  end

  test "reads work as GET, but a change is never made by a GET" do
    create_entry("articles", { "title" => "Listed" })

    get "/api/v2/list_entries", params: { collection: "articles", per_page: "5" }, headers: headers
    assert_equal [ "Listed" ], json.dig("data", "entries").map { |entry| entry["title"] }

    get "/api/v2/create_entry", params: { collection: "articles", data: { title: "Sneaky" } }, headers: headers
    assert_response :method_not_allowed
  end

  test "refusals are problem documents with a code and a hint an app can act on" do
    post "/api/v2/transition_entry", params: { id: create_entry("articles").id, action: "publish" }, headers:, as: :json

    assert_response :forbidden
    assert_equal "forbidden", json["code"]
    assert json["hint"].present?
  end

  test "the catalogue lists only what this connection can do" do
    get "/api/v2/operations", headers: headers

    names = json["data"].map { |operation| operation["name"] }
    assert_includes names, "update_entry"
    assert_not_includes names, "update_navigation"
    assert_equal false, json["data"].find { |operation| operation["name"] == "update_entry" }.dig("annotations", "readOnlyHint")
  end

  test "authenticated answers are never cached, by the page cache or anyone else" do
    get "/api/v2/whoami", headers: headers

    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil response.headers["Surrogate-Key"]
  end

  test "a revoked grant or agent access switched off stops the next request" do
    @grant.revoke!
    get "/api/v2/whoami", headers: headers
    assert_response :unauthorized

    Nibble::AgentAccess.update!(enabled: false)
    get "/api/v2/whoami", headers: headers
    assert_response :not_found
  end
end
