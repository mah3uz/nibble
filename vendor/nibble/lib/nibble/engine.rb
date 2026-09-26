require "rails"

module Nibble
  # Not isolated, so Nibble::Cp::EntriesController keeps its name. A site's own app/ still loads, and its views are looked in first.
  class Engine < Rails::Engine
    paths.add "lib", eager_load: true
    paths.add "app", eager_load: true, glob: "{*,*/concerns}", exclude: %w[views]

    initializer "nibble.autoload", before: :set_autoload_paths do
      Rails.autoloaders.main.ignore(root.join("lib/nibble.rb"), root.join("lib/nibble/engine.rb"),
        root.join("lib/commands"), root.join("lib/middleware"))
    end

    # The runtime migrator is set too, or the pending-migration check never sees Nibble's.
    initializer "nibble.migrations" do |app|
      app.config.paths["db/migrate"].concat(paths["db/migrate"].existent)
      ActiveRecord::Migrator.migrations_paths = app.config.paths["db/migrate"].to_a
    end

    # Each railtie's routes are unshifted and the site's come last, so Nibble places its own around them.
    initializer "nibble.routes", before: :set_routes_reloader_hook do |app|
      app.routes_reloader.paths.unshift(root.join("config/routes/core.rb").to_s)
      app.routes_reloader.paths.push(root.join("config/routes/catch_all.rb").to_s)
    end

    initializer "nibble.active_storage" do
      ActiveSupport.on_load(:active_storage_attachment) do
        def self.polymorphic_class_for(name) = Nibble::Records::MODELS.key?(name) ? Nibble::Records.model(name) : super
      end
    end

    initializer "nibble.middleware" do |app|
      require_relative "../middleware/nibble_redirects_middleware"
      require_relative "../middleware/form_request_limit_middleware"
      app.config.middleware.insert_before Rack::Runtime, NibbleRedirectsMiddleware
      app.config.middleware.insert_before Rack::MethodOverride, FormRequestLimitMiddleware
    end

    # Bundler loads Nibble itself, so it outlives a reload; what it memoised would hold the previous classes.
    config.to_prepare do
      ::Nibble.config = nil
      ::Nibble.reset_schema!
      ::Nibble.boot!
    end

    config.after_initialize do
      ::Nibble::Environment.boot!(serving: Rails.const_defined?(:Server)) if ::Nibble::Environment.deployed?
      # The types describe the theme this server renders, whatever wrote them last.
      ::Nibble.schema_changed! if Rails.application.config.enable_reloading && Rails.const_defined?(:Server)
    end
  end
end
