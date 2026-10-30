require "test_helper"

class SchemaTypesCommandTest < ActiveSupport::TestCase
  setup do
    @site = Pathname(Dir.mktmpdir("nibble-site-schema"))
    @site.join("globals").mkpath
    @site.join("globals/site.yml").write({ "title" => "Site", "blueprint" => { "tabs" => { "main" => { "sections" => [ { "fields" => [ { "handle" => "name", "field" => { "type" => "text" } } ] } ] } } } }.to_yaml)
    @output = Pathname(Dir.mktmpdir("nibble-types")).join("types.d.ts")
    @original = Nibble.method(:site_schema_path)
    site = @site
    Nibble.define_singleton_method(:site_schema_path) { site }
    Nibble.reset_schema!
  end

  teardown do
    Nibble.define_singleton_method(:site_schema_path, @original)
    Nibble.reset_schema!
    FileUtils.rm_rf([ @site, @output.dirname ])
  end

  def types(*flags)
    capture_io { Rails::Command.invoke("nibble:schema:types", [ *flags, "--output", @output.to_s ]) }
    @output.read
  end

  test "--without-site types a theme against its own schema, so a site that drops a field can't fail the theme's check" do
    assert_no_match "social_links", types
    assert_match "social_links", types("--without-site")
  end
end
