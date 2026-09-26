# Nibble: the Control Plane and themes render through Inertia, server-side from the SSR bundle.
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
  # Nil while the Vite dev server runs: inertia-rails only renders through Vite when no URL is set, and the built
  # bundle Puma would use instead is whatever theme last built it.
  config.ssr_url = lambda do
    "http://localhost:#{ENV.fetch('INERTIA_SSR_PORT', 13714)}" unless InertiaRails::SSR.vite_dev_server_running?
  end
end
