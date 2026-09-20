Rails.application.config.to_prepare do
  WebAuthn.configure do |config|
    config.allowed_origins = [ Nibble.config.url ].compact
    config.rp_name = "Nibble"
    config.credential_options_timeout = 120_000
  end
end
