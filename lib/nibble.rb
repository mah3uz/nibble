module Nibble
  VERSION = "0.14.0".freeze
  # Where releases come from.
  REPOSITORY = "https://github.com/mah3uz/nibble.git".freeze
  CHANGELOGS_FEED = "https://nibble.ink/api/v1/changelogs".freeze
  SCHEMA_FORMAT = 1
  THEME_API_VERSION = 1
  CONTENT_FORMAT_VERSION = 1
  DEFAULT_THEME = "crumbs".freeze
  # A theme is layouts, views and schema; content is a site's own. This is the installer's to offer, not a theme's to carry.
  STARTER_CONTENT = Pathname(__dir__).join("nibble/starter_content").freeze

  class << self
    def config
      @config ||= Config.new(config_values)
    end

    attr_writer :config

    def schema
      if Rails.application.config.enable_reloading && !Current.schema_checked
        Current.schema_checked = true
        schema_reloader.execute_if_updated
      end
      @schema ||= Schema.load(config)
    end

    # The index is read against the schema, so it cannot outlive one.
    def reset_schema!
      @schema = nil
      Files.reset!
    end

    def build_theme = config.theme

    # A missing manifest entry still raises: the wrong CSS is worse than none.
    def theme_stylesheet
      return nil unless config.theme_path&.join("styles", "theme.css")&.file?

      "/themes/#{build_theme}/styles/theme.css"
    end

    def site_url = ENV["SITE_URL"].presence || "http://localhost:#{ENV.fetch("PORT", 3100)}"

    def config_file = Rails.root.join("config/nibble.yml")

    def config_values
      values = config_file.exist? ? Rails.application.config_for(:nibble).to_h.deep_stringify_keys : {}
      # One settings file serves every environment, so the environment decides the theme and the URL.
      values["theme"] = ENV["NIBBLE_THEME"].presence || values["theme"].presence || DEFAULT_THEME
      values["url"] = ENV["SITE_URL"].presence || values["url"].presence || site_url
      values
    end

    def boot!
      Events.reset!
      Lifecycle.reset_guards!
      Events.subscribe("record.*", Subscribers::Relations)
      Events.subscribe("record.*", Subscribers::Uris)
      Events.subscribe("record.*", Subscribers::Audit)
      Events.subscribe("workflow.*", Subscribers::Audit)
      Events.subscribe("workflow.*", Subscribers::Notifications, async: true)
      Events.subscribe("record.*", Subscribers::PageCache, async: true)
      Events.subscribe("record.*", Subscribers::Search, async: true)
      Webhooks::PATTERNS.each { |pattern| Events.subscribe(pattern, Subscribers::Webhooks, async: true) }

      entries = Records::Resolver.new(Records::Entry, scope_key: "collections", scope_column: :collection)
      terms = Records::Resolver.new(Records::Term, scope_key: "taxonomies", scope_column: :taxonomy)
      Resolvers.register("entry", entries)
      Resolvers.register("term", terms)
      Resolvers.register("asset", Records::AssetResolver.new)
      LinkTypes.register("entry", title: "Entry", resolver: entries)
      LinkTypes.register("term", title: "Term", resolver: terms)
    end

    def core_schema_path = Rails.root.join("lib/nibble/core_schema")
    def site_schema_path = Rails.root.join("schema")
    def content_path = Rails.root.join("content")
    def themes_path = Rails.root.join("themes")

    private

    def schema_reloader
      @schema_reloader ||= begin
        dirs = [ core_schema_path, site_schema_path, themes_path ].to_h { |dir| [ dir.to_s, [ "yml" ] ] }
        ActiveSupport::FileUpdateChecker.new([], dirs) { reset_schema! }
      end
    end
  end
end
