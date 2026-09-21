# frozen_string_literal: true

InertiaRails.configure do |config|
  config.version = ViteRuby.digest
  config.encrypt_history = true
  config.always_include_errors_hash = true
  config.use_script_element_for_initial_page = true
  config.use_data_inertia_head_attribute = true

  # SSR: in development the Vite dev server renders (detected automatically); otherwise the
  # Node SSR process (`bin/vite ssr`) renders when its bundle has been built.
  config.ssr_enabled = ViteRuby.config.ssr_build_enabled
  config.ssr_bundle = Rails.root.join("public/vite-ssr/ssr.js").to_s
  # Puma spawns the SSR process with this environment, so one variable moves both ends of the conversation.
  config.ssr_url = "http://localhost:#{ENV.fetch('INERTIA_SSR_PORT', 13714)}"
end
