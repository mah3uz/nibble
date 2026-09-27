require "test_helper"
require "webmock"

class Nibble::OauthTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include WebMock::API

  LOOPBACK = "http://127.0.0.1:53682/callback".freeze
  CIMD = "https://app.example.test/oauth/client.json".freeze

  setup do
    Nibble::AgentAccess.update!(enabled: true)
    sign_in_as users(:admin)
    @verifier = SecureRandom.urlsafe_base64(48)
    @challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@verifier), padding: false)
  end

  teardown do
    WebMock.reset!
    WebMock.disable!
  end

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]
  def json = JSON.parse(response.body)
  def issuer = Nibble::Oauth.issuer(ActionDispatch::TestRequest.create)
  def query(url) = Rack::Utils.parse_query(URI.parse(url).query)

  def ask(client_id: Nibble::OauthClient::CLI_ID, redirect_uri: LOOPBACK, **extra)
    get "/oauth/authorize", params: { response_type: "code", client_id:, redirect_uri:, code_challenge: @challenge,
                                      code_challenge_method: "S256", state: "s1" }.merge(extra)
  end

  def approve(preset: "draft", **options)
    ask(**options)
    post "/oauth/authorize", params: { request_id: props["request_id"], decision: "approve", preset: }
    query(response.location)
  end

  def exchange(code, verifier: @verifier, redirect_uri: LOOPBACK, client_id: Nibble::OauthClient::CLI_ID)
    post "/oauth/token", params: { grant_type: "authorization_code", code:, code_verifier: verifier, redirect_uri:, client_id: }.compact
  end

  def tokens(preset: "draft")
    exchange(approve(preset:)["code"])
    json
  end

  def refresh(token) = post("/oauth/token", params: { grant_type: "refresh_token", refresh_token: token, client_id: Nibble::OauthClient::CLI_ID })

  def principal(access) = Nibble::Principal.new(user: users(:admin), grant: Nibble::Oauth.authenticate(access, resources: Nibble::Oauth.resources(ActionDispatch::TestRequest.create).values))

  test "everything answers 404 until an administrator turns agent access on" do
    Nibble::AgentAccess.update!(enabled: false)

    get "/.well-known/oauth-authorization-server"
    assert_response :not_found
    post "/oauth/token", params: { grant_type: "refresh_token" }
    assert_response :not_found
    ask
    assert_match "turned off", props["message"]
  end

  test "discovery says exactly what MCP clients check before they trust the server" do
    get "/.well-known/oauth-authorization-server"
    metadata = json

    assert_equal issuer, metadata["issuer"]
    assert_equal %w[S256], metadata["code_challenge_methods_supported"], "a client must refuse a server that allows plain PKCE"
    assert_includes metadata["token_endpoint_auth_methods_supported"], "none"
    assert metadata["client_id_metadata_document_supported"]
    assert metadata["authorization_response_iss_parameter_supported"]
    assert_nil metadata["device_authorization_endpoint"], "device sign-in stays hidden until it's turned on"

    get "/.well-known/oauth-protected-resource/mcp"
    assert_equal "#{issuer}/mcp", json["resource"]
    assert_equal [ issuer ], json["authorization_servers"]
  end

  test "a person approves, the app gets a code bound to its PKCE challenge, and swaps it for tokens" do
    params = approve

    assert_equal "s1", params["state"]
    assert_equal issuer, params["iss"], "the issuer lets the client detect a mix-up with another server"
    exchange(params["code"])

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "Bearer", json["token_type"]
    grant = Nibble::Grant.last
    assert_equal [ "draft", "Nibble CLI", users(:admin) ], [ grant.preset, grant.name, grant.user ]
    assert Nibble::Records::Notification.exists?(user_id: users(:admin).id, kind: "apps.connected"), "a new app is announced to its owner"
  end

  test "a loopback redirect may use any port, but nothing else may differ" do
    ask(redirect_uri: "http://127.0.0.1:61000/callback")
    assert props["request_id"]

    ask(redirect_uri: "http://127.0.0.1:61000/elsewhere")
    assert_response :bad_request
    assert_nil response.location, "an unregistered redirect is never followed"
  end

  test "an unregistered or dangerous redirect is refused on the page, never redirected to" do
    [ "https://evil.example/callback", "javascript:alert(1)", "data:text/html,hi" ].each do |uri|
      ask(redirect_uri: uri)
      assert_response :bad_request, uri
      assert_nil response.location
    end
  end

  test "without S256 PKCE the request goes back to the app as an error" do
    ask(code_challenge_method: "plain")
    assert_equal "invalid_request", query(response.location)["error"]

    ask(code_challenge: nil)
    assert_equal "invalid_request", query(response.location)["error"]
  end

  test "a code can't be swapped without the verifier that matches its challenge" do
    code = approve["code"]
    exchange(code, verifier: nil)
    assert_equal "invalid_grant", json["error"], "no downgrade to a PKCE-less exchange"

    exchange(approve["code"], verifier: SecureRandom.urlsafe_base64(48))
    assert_equal "invalid_grant", json["error"]
  end

  test "a replayed code is refused and revokes what the first use received" do
    code = approve["code"]
    exchange(code)
    access = json["access_token"]

    exchange(code)
    assert_equal "invalid_grant", json["error"]
    assert_nil principal(access).grant, "a code seen twice may have been stolen, so its tokens die too"
  end

  test "the code only works for the client and redirect it was issued for" do
    code = approve["code"]
    exchange(code, redirect_uri: "http://127.0.0.1:1/callback")
    assert_equal "invalid_grant", json["error"]

    exchange(approve["code"], client_id: "someone-else")
    assert_equal "invalid_grant", json["error"]
  end

  test "token requests are read from the form body only" do
    code = approve["code"]
    post "/oauth/token?grant_type=authorization_code&code=#{code}&code_verifier=#{@verifier}&redirect_uri=#{CGI.escape(LOOPBACK)}&client_id=nibble-cli"

    assert_equal "unsupported_grant_type", json["error"]
  end

  test "refresh tokens rotate, and an old one used again disconnects the app" do
    first = tokens
    refresh(first["refresh_token"])
    second = json
    assert second["access_token"].present?

    refresh(first["refresh_token"])
    assert_response :success, "two refreshes at the same moment are one client, not an attacker"

    travel 1.minute do
      refresh(first["refresh_token"])
      assert_equal "invalid_grant", json["error"]
      assert_nil principal(second["access_token"]).grant, "reuse means a copy exists, so the whole grant ends"
    end
  end

  test "declining sends the app back with access_denied, and only to its registered address" do
    ask
    post "/oauth/authorize", params: { request_id: props["request_id"], decision: "deny" }

    params = query(response.location)
    assert response.location.start_with?(LOOPBACK)
    assert_equal [ "access_denied", "s1", issuer ], params.values_at("error", "state", "iss")
    assert_equal 0, Nibble::Grant.count
  end

  test "handing over everything needs a freshly confirmed password" do
    Nibble::Current.session.update!(elevated_at: 20.minutes.ago)
    ask
    post "/oauth/authorize", params: { request_id: props["request_id"], decision: "approve", preset: "everything" }

    assert_equal 0, Nibble::Grant.count
  end

  test "people whose role can't connect apps are told so and nothing is granted" do
    sign_in_as users(:editor)
    ask

    assert_match "can't connect apps", props["message"]
  end

  test "the consent page can't be framed" do
    ask

    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_match "frame-ancestors 'none'", response.headers["Content-Security-Policy"].to_s
  end

  test "an app's reach is the person's roles, the grant and the site's settings, all three, checked on every call" do
    access = tokens["access_token"]
    entry = create_entry("articles", {}, actor: users(:admin))

    assert Nibble::Lifecycle.call(entry, :save, { "title" => "By an agent" }, actor: principal(access)).ok?
    assert Nibble::Lifecycle.call(entry.reload, :publish, {}, actor: principal(access)).forbidden?, "Draft never publishes"

    Nibble::AgentAccess.update!(areas: { "entries.articles" => { "read" => true, "write" => false } })
    assert Nibble::Lifecycle.call(entry.reload, :save, { "title" => "Again" }, actor: principal(access)).forbidden?,
      "turning Write off applies at once, without anyone reconnecting"

    Nibble::AgentAccess.update!(enabled: false)
    assert_nil Nibble::Oauth.authenticate(access, resources: Nibble::Oauth.resources(ActionDispatch::TestRequest.create).values)
  end

  test "an edit through an app is recorded as the person, via the app" do
    access = tokens["access_token"]
    entry = create_entry("articles", {}, actor: users(:admin))
    Nibble::Lifecycle.call(entry, :save, { "title" => "By an agent" }, actor: principal(access))
    Nibble::Events.dispatch_pending

    revision = entry.revisions.reorder(number: :desc).first
    assert_equal [ users(:admin), "Nibble CLI" ], [ revision.actor, revision.grant.name ]
    assert_equal Nibble::Grant.last.id, Nibble::Records::AuditEntry.where(subject_id: entry.id).last.grant_id
  end

  test "an app described by a metadata document is fetched safely and must name itself" do
    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: true)
    resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
    stub_request(:get, CIMD).to_return(status: 200, headers: { "Content-Type" => "application/json" },
      body: { client_id: CIMD, client_name: "Example App", redirect_uris: [ "https://app.example.test/callback" ] }.to_json)

    ask(client_id: CIMD, redirect_uri: "https://app.example.test/callback")
    assert_equal [ "Example App", "app.example.test", "app.example.test" ], props["client"].values_at("name", "id_host", "redirect_host")

    stub_request(:get, "https://other.example.test/client.json").to_return(status: 200,
      body: { client_id: CIMD, redirect_uris: [ "https://other.example.test/cb" ] }.to_json)
    ask(client_id: "https://other.example.test/client.json", redirect_uri: "https://other.example.test/cb")
    assert_match "different client_id", props["message"]
  ensure
    Nibble::Outbound::Guard.resolver = resolver
  end

  test "a metadata document on a private address is never fetched" do
    resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "169.254.169.254" ] }

    ask(client_id: "https://metadata.internal.test/client.json", redirect_uri: "https://metadata.internal.test/cb")
    assert_match "private or reserved", props["message"]
  ensure
    Nibble::Outbound::Guard.resolver = resolver
  end

  test "apps may register themselves, but only as public clients with safe redirects" do
    post "/oauth/register", params: { client_name: "Some Agent", redirect_uris: [ "http://localhost:4000/cb" ] }, as: :json
    assert_response :created
    assert_equal "none", json["token_endpoint_auth_method"]
    assert_not Nibble::OauthClient.find_by(client_id: json["client_id"]).verified?, "a self-registered app is shown as unverified"

    post "/oauth/register", params: { redirect_uris: [ "javascript:alert(1)" ] }, as: :json
    assert_equal "invalid_redirect_uri", json["error"]
    post "/oauth/register", params: { redirect_uris: [ "https://a.test/cb" ], token_endpoint_auth_method: "client_secret_basic" }, as: :json
    assert_equal "invalid_client_metadata", json["error"]
  end

  test "signing in with a code works only when turned on, and never hands over everything" do
    post "/oauth/device_authorization", params: { client_id: Nibble::OauthClient::CLI_ID }
    assert_response :not_found

    Nibble::AgentAccess.update!(device_sign_in: true)
    post "/oauth/device_authorization", params: { client_id: Nibble::OauthClient::CLI_ID }
    device = json
    post "/oauth/token", params: { grant_type: Nibble::Oauth::DEVICE_GRANT, device_code: device["device_code"], client_id: "nibble-cli" }
    assert_equal "authorization_pending", json["error"]

    post "/cp/device", params: { code: device["user_code"].downcase }
    assert_not props["presets"].find { |preset| preset["value"] == "everything" }["available"]
    post "/oauth/authorize", params: { request_id: props["request_id"], decision: "approve", preset: "read" }

    travel 6.seconds do
      post "/oauth/token", params: { grant_type: Nibble::Oauth::DEVICE_GRANT, device_code: device["device_code"], client_id: "nibble-cli" }
      assert json["access_token"].present?
      assert_equal "device", Nibble::Grant.last.via
    end
  end
end
