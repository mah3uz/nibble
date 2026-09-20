require "test_helper"
require_relative "../../lib/middleware/basic_auth_middleware"

class BasicAuthMiddlewareTest < ActiveSupport::TestCase
  setup do
    ENV["BASIC_AUTH_USER"] = "tester"
    ENV["BASIC_AUTH_PASSWORD"] = "secret"
    @app = ->(env) { [ 200, {}, [ "ok" ] ] }
    @middleware = BasicAuthMiddleware.new(@app)
  end

  teardown do
    ENV.delete("BASIC_AUTH_USER")
    ENV.delete("BASIC_AUTH_PASSWORD")
  end

  test "/up passes through without credentials, so Kamal's health check keeps working" do
    status, = @middleware.call(Rack::MockRequest.env_for("/up"))
    assert_equal 200, status
  end

  test "every other path is rejected without credentials" do
    status, headers = @middleware.call(Rack::MockRequest.env_for("/"))
    assert_equal 401, status
    assert headers["www-authenticate"]
  end

  test "the right username and password are accepted" do
    env = Rack::MockRequest.env_for("/", "HTTP_AUTHORIZATION" => "Basic #{Base64.encode64('tester:secret')}")
    status, = @middleware.call(env)
    assert_equal 200, status
  end

  test "the wrong password is rejected" do
    env = Rack::MockRequest.env_for("/", "HTTP_AUTHORIZATION" => "Basic #{Base64.encode64('tester:wrong')}")
    status, = @middleware.call(env)
    assert_equal 401, status
  end

  test "raises a clear error instead of silently allowing access when unconfigured" do
    ENV.delete("BASIC_AUTH_USER")
    env = Rack::MockRequest.env_for("/", "HTTP_AUTHORIZATION" => "Basic #{Base64.encode64('tester:secret')}")
    assert_raises(RuntimeError) { @middleware.call(env) }
  end
end
