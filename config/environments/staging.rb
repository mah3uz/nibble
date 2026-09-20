# Staging runs the production configuration with its own databases
# (storage/staging*.sqlite3), credentials (config/credentials/staging.yml.enc) and environment
# variables (config/deploy.staging.yml).
require_relative "production"
require_relative "../../lib/middleware/basic_auth_middleware"

Rails.application.configure do
  # Keep staging out of search engines (robots.txt already disallows everything off the production URL).
  config.action_dispatch.default_headers["X-Robots-Tag"] = "noindex, nofollow"

  # Keep staging out of public view entirely.
  # Credentials: bin/rails credentials:edit --environment staging (basic_auth.username/password).
  config.middleware.insert_before NibbleRedirectsMiddleware, BasicAuthMiddleware
end
