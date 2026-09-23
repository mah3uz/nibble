module Nibble
  class Config
    Locale = Data.define(:code, :default, :url_prefix, :search_tokenizer)

    # A site can add reserved paths but never drop these: without /admin an entry can claim the control panel.
    RESERVED_PATHS = %w[/admin /api /forms /assets /nibble-assets /up /sitemap.xml /robots.txt /.well-known].freeze

    DEFAULTS = {
      "load_defaults" => "0.0",
      "locales" => [ { "code" => "en", "default" => true, "url_prefix" => "" } ],
      "disable" => [],
      "reserved_paths" => [],
      "trash" => { "retention_days" => 30 },
      "assets" => {
        "max_upload_mb" => 50,
        "additional_extensions" => [],
        "presets" => {
          "card" => { "w" => 960, "h" => 640, "fit" => "crop", "srcset" => [ 480, 960, 1440 ] },
          "hero" => { "w" => 1920, "h" => 1080, "fit" => "crop", "srcset" => [ 768, 1280, 1920, 2560 ] },
          "content" => { "w" => 1440, "h" => 1440, "fit" => "contain", "srcset" => [ 640, 960, 1440 ] },
          "og" => { "w" => 1200, "h" => 630, "fit" => "crop" }
        }
      },
      "outbound" => { "allowed_hosts" => [], "secrets" => [], "config" => {} }
    }.freeze

    attr_reader :load_defaults, :theme, :url, :locales, :reserved_paths, :disable, :trash_retention_days, :asset_extensions, :asset_presets, :max_upload_bytes,
                :outbound_allowed_hosts, :outbound_secrets, :outbound_config

    def initialize(values, themes_path: nil, site_schema_path: nil, content_path: nil, published_path: nil)
      values = DEFAULTS.deep_merge(values.to_h.deep_stringify_keys.compact)
      @themes_path = themes_path && Pathname(themes_path)
      @site_schema_path = site_schema_path && Pathname(site_schema_path)
      @content_path = content_path && Pathname(content_path)
      @published_path = published_path && Pathname(published_path)
      @load_defaults = values["load_defaults"].presence.to_s
      @theme = values["theme"].presence
      @url = values["url"].to_s
      @locales = parse_locales(values["locales"])
      @reserved_paths = (RESERVED_PATHS | Array(values["reserved_paths"]).map(&:to_s)).freeze
      @disable = Array(values["disable"]).map(&:to_s).freeze
      @trash_retention_days = values.dig("trash", "retention_days") || 30
      assets = values["assets"].to_h
      @asset_extensions = Array(assets["additional_extensions"]).map { |ext| ext.to_s.downcase.delete_prefix(".") }.freeze
      @asset_presets = parse_presets(assets["presets"])
      @max_upload_bytes = (assets["max_upload_mb"] || 50).to_i.megabytes
      outbound = values["outbound"].to_h
      @outbound_allowed_hosts = Array(outbound["allowed_hosts"]).map { |host| host.to_s.downcase }.freeze
      @outbound_secrets = Array(outbound["secrets"]).map(&:to_s).freeze
      @outbound_config = outbound["config"].to_h.deep_dup.freeze
      freeze
    end

    # New behaviour ships off: a site opts in by raising load_defaults, never by upgrading.
    def behaviour?(introduced_in) = Release.at_least?(load_defaults, introduced_in)

    def default_locale = locales.find(&:default)

    def locale(code) = locales.find { |locale| locale.code == code.to_s }

    def theme_path = theme && (@themes_path ? @themes_path.join(theme) : Nibble.theme_path(theme))

    # A test fixture points this somewhere of its own, so a site's schema can't reach into what it declares.
    def site_schema_path = @site_schema_path || Nibble.site_schema_path

    def content_path = @content_path || Nibble.content_path

    # Owned outright: what is not published from the folder is deleted from it.
    # Behaviour a site would notice ships switched off until the site raises load_defaults to the release that brought it.
    def defaults_at_least?(version)
      Gem::Version.correct?(load_defaults) && Gem::Version.new(load_defaults) >= Gem::Version.new(version)
    end

    def published_path = @published_path || Rails.public_path.join(Files::PUBLISHED)

    def active_theme = theme_path && Theme.load(theme_path)

    private

    def parse_presets(raw)
      raw.to_h.to_h do |name, preset|
        raise ConfigError.new("assets.presets", "preset names can only use lowercase letters, numbers, dashes and underscores") unless name.to_s.match?(/\A[a-z0-9_-]+\z/)

        preset = preset.to_h.stringify_keys
        unless %w[w h].all? { |key| preset[key].is_a?(Integer) && preset[key].positive? }
          raise ConfigError.new("assets.presets.#{name}", "needs a positive w and h")
        end
        raise ConfigError.new("assets.presets.#{name}", "fit must be crop or contain") unless %w[crop contain].include?(preset["fit"] ||= "crop")
        unless Array(preset["srcset"]).all? { |width| width.is_a?(Integer) && width.positive? }
          raise ConfigError.new("assets.presets.#{name}", "srcset must be a list of widths")
        end

        [ name.to_s, preset.freeze ]
      end.freeze
    end

    def parse_locales(raw)
      locales = Array(raw).map do |entry|
        entry = entry.to_h.stringify_keys
        raise ConfigError.new("locales", "each locale needs a code") if entry["code"].blank?

        tokenizer = entry["search_tokenizer"].presence || "porter"
        raise ConfigError.new("locales", "search_tokenizer must be porter or trigram") unless %w[porter trigram].include?(tokenizer)

        Locale.new(code: entry["code"].to_s, default: entry["default"] == true, url_prefix: entry["url_prefix"].to_s, search_tokenizer: tokenizer)
      end
      raise ConfigError.new("locales", "at least one locale is required") if locales.empty?
      raise ConfigError.new("locales", "exactly one locale must be the default") unless locales.count(&:default) == 1
      raise ConfigError.new("locales", "locale codes must be unique") unless locales.map(&:code).uniq.size == locales.size

      locales.freeze
    end
  end
end
