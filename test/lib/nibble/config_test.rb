require "test_helper"

class Nibble::ConfigTest < ActiveSupport::TestCase
  def config(overrides = {})
    Nibble::Config.new({ "locales" => [ { "code" => "en", "default" => true } ] }.merge(overrides))
  end

  test "the site URL is the SITE_URL deployments set, not whatever the install wrote" do
    assert_equal ENV.fetch("SITE_URL"), Nibble.config.url,
      "one settings file serves every environment, so a deploy's SITE_URL has to win over it"
  end

  test "a site without a theme runs on the core schema alone" do
    assert_nil config.theme
    assert_nil config.theme_path
  end

  test "the active theme resolves to its folder under themes/" do
    assert_equal Rails.root.join("themes/starter"), config("theme" => "starter").theme_path
  end

  test "the theme the layout asks for is the theme the settings name" do
    Nibble.config = config("theme" => "starter")

    assert_equal "starter", Nibble.build_theme,
      "vite compiles the theme config/nibble.yml names, so a shell asking for another one serves a site the wrong stylesheet"
  ensure
    Nibble.config = nil
  end

  test "routing and queries need exactly one default locale to fall back to" do
    error = assert_raises(Nibble::ConfigError) { config("locales" => [ { "code" => "en" }, { "code" => "de" } ]) }
    assert_match "exactly one locale must be the default", error.message

    assert_raises(Nibble::ConfigError) { config("locales" => []) }
    assert_equal "en", config.default_locale.code
  end

  test "duplicate locale codes would make translations ambiguous" do
    error = assert_raises(Nibble::ConfigError) do
      config("locales" => [ { "code" => "en", "default" => true }, { "code" => "en" } ])
    end
    assert_match "unique", error.message
  end

  test "the shipped config loads for this environment" do
    assert Nibble.config.default_locale
    assert_includes Nibble.config.reserved_paths, "/admin"
  end

  test "an install with no config file still has every setting the app depends on" do
    bare = Nibble::Config.new({})

    assert_equal "en", bare.default_locale.code
    assert_equal 30, bare.trash_retention_days
    assert_equal 50.megabytes, bare.max_upload_bytes
    assert_equal %w[card content hero og], bare.asset_presets.keys.sort
  end

  test "reserved paths hold even when a site's config says nothing, so no entry can claim /admin" do
    assert_includes Nibble::Config.new({}).reserved_paths, "/admin"
    assert_includes config("reserved_paths" => []).reserved_paths, "/admin"
  end

  test "a site adds reserved paths rather than replacing the ones protecting the app" do
    paths = config("reserved_paths" => [ "/shop" ]).reserved_paths

    assert_includes paths, "/shop"
    assert_includes paths, "/admin"
  end

  test "a site's asset preset replaces one of ours by name without dropping the rest" do
    presets = config("assets" => { "presets" => { "card" => { "w" => 100, "h" => 100 } } }).asset_presets

    assert_equal 100, presets["card"]["w"]
    assert_equal 1200, presets["og"]["w"]
  end

  test "a site's own schema directory is the last layer, so its files win and upgrades never touch them" do
    layers = Nibble::Schema.layers(config("theme" => "starter"))

    assert_equal %i[core theme site], layers.map(&:first)
    assert_equal Nibble.site_schema_path, layers.last.last
    assert Nibble.site_schema_path.directory?, "schema/ must exist for a site to drop files into"
  end

  test "a site that has not opted in keeps the old behaviour after an upgrade" do
    assert_not config.behaviour?("0.2"), "upgrading must not change how a site behaves on its own"
    assert_not Nibble::Config.new({}).behaviour?("0.2")
  end

  test "raising load_defaults is what turns new behaviour on, one version at a time" do
    site = config("load_defaults" => "0.2")

    assert site.behaviour?("0.2")
    assert site.behaviour?("0.1")
    assert_not site.behaviour?("0.3"), "a site never gets behaviour from a version it has not opted into"
  end

  test "schema errors point at the file and key so authors can find the problem" do
    error = Nibble::SchemaError.new(file: Rails.root.join("vendor/nibble/core_schema/collections/posts.yml"), key: "route", reason: "is required")
    assert_equal "vendor/nibble/core_schema/collections/posts.yml: route: is required", error.message
  end

  test "load_defaults opts a site into the behaviour of the release it names, and no later one" do
    config = ->(value) { Nibble::Config.new({ "load_defaults" => value }) }

    assert config.("0.15.0").defaults_at_least?("0.15.0")
    assert config.("0.16.2").defaults_at_least?("0.15.0")
    assert_not config.("0.14.7").defaults_at_least?("0.15.0")
    assert_not config.(nil).defaults_at_least?("0.15.0"), "a site that never set it keeps every behaviour off"
    assert_not config.("latest").defaults_at_least?("0.15.0"), "a value that is not a version opts into nothing"
  end
end
