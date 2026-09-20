require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module NibbleApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware commands])
    Rails.autoloaders.main.ignore("#{__dir__}/../lib/nibble/routes", "#{__dir__}/../lib/nibble/db",
      "#{__dir__}/../lib/nibble/app")

    # Ours, laid out as Rails lays out app/, so Admin::EntriesController keeps its name. A site's own
    # app/ is still loaded, and its views are looked in first.
    config.paths.add "lib/nibble/app", eager_load: true, glob: "{*,*/concerns}", exclude: %w[views]
    config.paths["app/views"] << "lib/nibble/app/views"

    config.paths["config/routes.rb"] = [
      "lib/nibble/routes/core.rb",
      "config/routes.rb",
      "lib/nibble/routes/catch_all.rb"
    ]

    config.after_initialize do
      Nibble::Environment.boot!(serving: Rails.const_defined?(:Server)) if Nibble::Environment.deployed?
    end

    initializer "nibble.site_initializers", after: :load_config_initializers do |app|
      app.root.glob("site/initializers/*.rb").sort.each { |file| load file }
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")

    # Editors and scheduled publishing work in Australian time.
    config.time_zone = "Sydney"

    require_relative "../lib/middleware/nibble_redirects_middleware"
    require_relative "../lib/middleware/form_request_limit_middleware"
    config.middleware.insert_before Rack::Runtime, NibbleRedirectsMiddleware
    config.middleware.insert_before Rack::MethodOverride, FormRequestLimitMiddleware
  end
end
