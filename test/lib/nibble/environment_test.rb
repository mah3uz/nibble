require "test_helper"

class Nibble::EnvironmentTest < ActiveSupport::TestCase
  class Credentials
    def initialize(values) = @values = values
    def secret_key_base = @values[:secret_key_base]
    def dig(*keys) = @values.dig(*keys)
  end

  def findings(url: "https://example.com", env: "production", theme: nil, **credentials)
    config = Nibble::Config.new({ "url" => url, "theme" => theme, "locales" => [ { "code" => "en", "default" => true } ] })
    Nibble::Environment.findings(config:, env:, credentials: Credentials.new({ secret_key_base: "x" }.merge(credentials)))
  end

  def errors(**) = findings(**).select { |finding| finding.level == :error }.map(&:source)

  test "development is not checked, so working locally is never blocked by production settings" do
    assert_empty findings(url: "http://localhost:3100", env: "development")
    assert_empty findings(url: "", env: "test")
  end

  test "a deployed site without SITE_URL is an error, because every published link depends on it" do
    assert_includes errors(url: ""), "SITE_URL"
    assert_includes errors(url: "not a url"), "SITE_URL"
  end

  test "SITE_URL pointing at localhost or plain http is caught before it publishes bad links" do
    assert_includes errors(url: "http://localhost:3100"), "SITE_URL"
    assert_includes errors(url: "https://127.0.0.1"), "SITE_URL"
    assert_includes errors(url: "http://example.com"), "SITE_URL"
    assert_not_includes errors(url: "https://example.com"), "SITE_URL"
  end

  test "credentials that cannot be read stop the site rather than failing one request at a time" do
    assert_includes errors(secret_key_base: nil), "RAILS_MASTER_KEY"
  end

  test "a theme named but not present is an error; no theme at all is only a warning" do
    assert_includes errors(theme: "missing-theme"), "theme"

    levels = findings.select { |finding| finding.source == "theme" }.map(&:level)
    assert_equal [ :warning ], levels, "a control-panel-only install is a choice, not a fault"
  end

  test "things that degrade the site rather than break it are warnings" do
    sources = findings.select { |finding| finding.level == :warning }.map(&:source)

    assert_includes sources, "mail"
    assert_includes sources, "backups"
  end

  test "every finding says what breaks, not just what is unset" do
    findings(url: "", secret_key_base: nil).each do |finding|
      assert_operator finding.message.length, :>, 25, "#{finding.source} must say the consequence: #{finding.message}"
    end
  end

  test "serving with a broken setting refuses to start and names every problem at once" do
    found = [ finding("SITE_URL", :error), finding("RAILS_MASTER_KEY", :error), finding("mail", :warning) ]
    out = StringIO.new

    error = assert_raises(Nibble::Environment::Unfit) { Nibble::Environment.boot!(serving: true, found:, out:) }

    assert_match "SITE_URL", error.message
    assert_match "RAILS_MASTER_KEY", error.message, "naming one at a time means one failed deploy per problem"
    assert_match "mail", out.string, "warnings still print"
  end

  test "a console or a migration still boots, so a bad setting can be fixed" do
    out = StringIO.new
    Nibble::Environment.boot!(serving: false, found: [ finding("SITE_URL", :error) ], out:)

    assert_match "fix these before the next deploy", out.string
  end

  test "a sound environment says nothing at all" do
    out = StringIO.new
    Nibble::Environment.boot!(serving: true, found: [], out:)

    assert_empty out.string
  end

  test "a schedule without one of Nibble's jobs is named, because nothing else would ever run it" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join("config").mkpath
      schedule = YAML.safe_load(Rails.root.join("config/recurring.yml").read)
      schedule["production"].delete("run_publishing_schedule")
      schedule["production"]["nightly_trash_purge"]["schedule"] = "at 5am every day"
      root.join("config/recurring.yml").write(YAML.dump(schedule))

      found = Nibble::Environment.findings(config: Nibble::Config.new({ "url" => "https://example.com" }), env: "production",
        credentials: Credentials.new({ secret_key_base: "x" }), root:).select { |finding| finding.source == "schedule" }

      assert_equal [ :warning ], found.map(&:level), "a site may run its schedule another way, so this never stops it serving"
      assert_match "Nibble::Jobs::RunSchedule", found.first.message
      assert_no_match "PurgeTrash", found.first.message, "moving a job to another time is the site's to decide"
    end
  end

  test "the schedule a site is installed with runs every job Nibble needs" do
    assert_empty findings.select { |finding| finding.source == "schedule" }
  end

  def finding(source, level) = Nibble::Environment::Finding.new(source:, message: "#{source} is not usable here", level:)
end
