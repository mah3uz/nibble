# Nibble: passkeys sign in to the Control Plane from the site's own address.
Rails.application.config.to_prepare do
  WebAuthn.configure do |config|
    config.allowed_origins = [ Nibble.config.url ].compact
    config.rp_name = URI(Nibble.config.url.to_s).host || "Nibble"
    config.credential_options_timeout = 120_000
  end
end
