# Gates the whole site behind HTTP Basic Auth, except Kamal's health check (/up must stay reachable
# without credentials). Staging only — see config/environments/staging.rb.
class BasicAuthMiddleware
  def initialize(app)
    @app = app
    @guard = Rack::Auth::Basic.new(app, "Staging") { |username, password| valid?(username, password) }
  end

  def call(env)
    return @app.call(env) if env["PATH_INFO"] == "/up"

    @guard.call(env)
  end

  private

  def valid?(username, password)
    ActiveSupport::SecurityUtils.secure_compare(username, expected_username) &
      ActiveSupport::SecurityUtils.secure_compare(password, expected_password)
  end

  def expected_username
    Rails.application.credentials.dig(:basic_auth, :username) || ENV["BASIC_AUTH_USER"] ||
      raise("BASIC_AUTH_USER is not configured")
  end

  def expected_password
    Rails.application.credentials.dig(:basic_auth, :password) || ENV["BASIC_AUTH_PASSWORD"] ||
      raise("BASIC_AUTH_PASSWORD is not configured")
  end
end
