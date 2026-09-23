require "test_helper"

class Nibble::MetadataTest < ActiveSupport::TestCase
  SETTINGS = <<~YAML.freeze
    # Ours, kept short on purpose.
    default: &default
      load_defaults: "0.15.0" # raised after reading the changelog
      url: https://notes.example

    production:
      <<: *default
  YAML

  setup do
    @root = Pathname(Dir.mktmpdir("nibble-metadata"))
    @root.join("config").mkpath
    @root.join("config/nibble.yml").write(SETTINGS)
  end

  teardown { FileUtils.rm_rf(@root) }

  test "recording an install leaves a person's settings and comments exactly as they wrote them" do
    Nibble::Release.record_install(version: "0.15.0", answers: { theme: "crumbs" }, root: @root)

    assert @root.join("config/nibble.yml").read.start_with?(SETTINGS.rstrip), "a YAML dump would have dropped every comment"
    assert_equal "0.15.0", Nibble::Release.installed(root: @root).version
  end

  test "the record never reaches the settings Rails reads" do
    Nibble::Release.record_install(version: "0.15.0", answers: { theme: "crumbs" }, root: @root)

    settings = Rails.application.config_for(@root.join("config/nibble.yml"), env: "production")

    assert_equal "https://notes.example", settings[:url]
    assert_nil settings[:install]
    assert_nil settings[:theme], "the install's answers are a record, not a setting"
  end

  test "recording again replaces the record rather than stacking a second one" do
    Nibble::Release.record_install(version: "0.14.0", root: @root)
    Nibble::Release.record_install(version: "0.15.0", root: @root)

    assert_equal 1, @root.join("config/nibble.yml").read.scan(Nibble::Metadata::MARKER).size
    assert_equal "0.15.0", Nibble::Release.installed(root: @root).version
  end

  test "what was ejected is kept beside the install, and neither overwrites the other" do
    source = "vendor/nibble/frontend/nibble-admin/pages/admin/Dashboard.vue"
    @root.join(source).dirname.mkpath
    @root.join(source).write("<template>ours</template>")

    Nibble::Release.record_install(version: "0.15.0", root: @root)
    Nibble::Eject.run(source, root: @root)

    assert_equal "0.15.0", Nibble::Release.installed(root: @root).version
    assert Nibble::Eject.ejected?(source, root: @root)
  end

  test "a site with no settings file yet still gets its record" do
    @root.join("config/nibble.yml").delete

    Nibble::Release.record_install(version: "0.15.0", root: @root)

    assert_equal "0.15.0", Nibble::Release.installed(root: @root).version
  end

  test "a theme named only in the record is never taken for the site's" do
    Nibble::Release.record_install(version: "0.15.0", answers: { theme: "crumbs" }, root: @root)
    @root.join("vendor/nibble/themes/crumbs/views").mkpath
    @root.join("vendor/nibble/themes/crumbs/theme.yml").write({ "name" => "Crumbs", "handle" => "crumbs" }.to_yaml)
    @root.join("vendor/nibble/themes/crumbs/package.json").write(%({"name":"@nibble-theme/crumbs","private":true}))

    note = Nibble::Generate.theme("almanac", root: @root).sole.note

    assert_match "add theme: almanac", note, "the settings name no theme, so there is no line of theirs to change"
    assert_equal "crumbs", Nibble::Release.installed(root: @root).answers[:theme], "the record keeps what was answered"
  end
end
