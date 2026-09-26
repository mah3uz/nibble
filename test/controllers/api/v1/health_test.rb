require "test_helper"

class Api::V1::HealthTest < ActionDispatch::IntegrationTest
  def body = JSON.parse(response.body)
  def auth(token) = { "Authorization" => "Bearer #{token}" }

  def with_ssr(url)
    config = InertiaRails.configuration
    # Read raw: the URL is a lambda, and restoring what it returned would leave a fixed URL for every later test.
    was = config.send(:options).values_at(:ssr_enabled, :ssr_url)
    config.ssr_enabled = true
    config.ssr_url = url
    yield
  ensure
    config.ssr_enabled, config.ssr_url = was
  end

  test "a monitor with a health token gets every check, uncached" do
    token = ApiToken.issue(name: "Uptime", scopes: %w[health]).last

    get "/api/v1/health", headers: auth(token)

    assert_includes [ 200, 503 ], response.status
    assert_equal %w[database queue storage ssr], body["checks"].map { |check| check["name"] }
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "a failing check answers 503, so a monitor that only reads status codes still notices" do
    token = ApiToken.issue(name: "Uptime", scopes: %w[health]).last
    closed = TCPServer.new("127.0.0.1", 0).then { |server| server.addr[1].tap { server.close } }

    with_ssr("http://127.0.0.1:#{closed}") { get "/api/v1/health", headers: auth(token) }

    assert_response :service_unavailable
    assert_equal "down", body["status"]
  end

  test "a content token can't read health, and a health token can't read content" do
    read = ApiToken.issue(name: "Site", scopes: %w[read]).last
    health = ApiToken.issue(name: "Uptime", scopes: %w[health]).last

    get "/api/v1/health", headers: auth(read)
    assert_response :forbidden

    get "/api/v1/schema", headers: auth(health)
    assert_response :forbidden
  end

  test "the health screen is for people who can see utilities" do
    sign_in_as users(:admin)
    get "/cp/utilities/health"
    assert_response :success

    sign_in_as users(:author)
    get "/cp/utilities/health"
    assert_response :forbidden
  end
end
