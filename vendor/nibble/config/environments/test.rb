Rails.application.configure do
  # Tests assert against the real production hostname, regardless of whatever SITE_URL a
  # developer's shell (mise, etc.) exports for local `bin/dev` use.
  ENV["SITE_URL"] = "https://example.com"
  # Tests follow config/nibble.yml, whichever theme a shell exports for running the site.
  ENV.delete("NIBBLE_THEME")
end
