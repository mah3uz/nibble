require "test_helper"

class Nibble::GenerateTest < ActiveSupport::TestCase
  setup { @root = Pathname(Dir.mktmpdir("nibble-generate")) }
  teardown { FileUtils.rm_rf(@root) }

  def yaml(relative) = YAML.safe_load_file(@root.join(relative))

  test "everything generated is valid schema, so a generator never hands back work to fix" do
    Nibble::Generate.collection("guides", root: @root)
    Nibble::Generate.taxonomy("regions", root: @root)
    Nibble::Generate.fieldset("seo_extra", root: @root)
    Nibble::Generate.global("contact", root: @root)
    Nibble::Generate.navigation("utility", root: @root)
    Nibble::Generate.form("enquiry", root: @root)

    items = Nibble::Schema::Loader.new(layers: [ [ :site, @root.join("schema") ] ]).load

    assert_equal 8, items.size
    assert_equal %w[blueprints collections fieldsets forms globals navigation taxonomies], items.map(&:kind).uniq.sort
  end

  test "a collection arrives with the blueprint it points at, or the schema would not load" do
    Nibble::Generate.collection("guides", root: @root)

    assert_equal [ "guide" ], yaml("schema/collections/guides.yml")["blueprints"]
    assert @root.join("schema/blueprints/collections/guides/guide.yml").file?
  end

  test "generated files land in the site's schema, never in Nibble's" do
    written = Nibble::Generate.collection("guides", root: @root).map(&:path)

    assert(written.all? { |path| path.start_with?("schema/") }, "site generators must not write into app/schema")
  end

  test "a name that isn't a valid handle is refused before anything is written" do
    error = assert_raises(Nibble::Generate::Refused) { Nibble::Generate.collection("Bad-Handle", root: @root) }

    assert_match "lowercase", error.message
    assert_not @root.join("schema").exist?
  end

  test "a clash is refused whole, so a half-made collection is never left behind" do
    Nibble::Generate.collection("guides", root: @root)
    @root.join("schema/collections/guides.yml").delete

    error = assert_raises(Nibble::Generate::Refused) { Nibble::Generate.collection("guides", root: @root) }

    assert_match "guide.yml already exists", error.message
    assert_not @root.join("schema/collections/guides.yml").exist?, "the collection must not be written when its blueprint can't be"
  end

  test "a plugin says plainly that there is nothing to plug into yet" do
    error = assert_raises(Nibble::Generate::Refused) { Nibble::Generate.plugin("acme", root: @root) }

    assert_match "no extension API", error.message
  end

  test "a generated theme is the site's own copy, and ours is left alone" do
    starter

    Nibble::Generate.theme("almanac", root: @root)

    assert_equal "almanac", yaml("themes/almanac/theme.yml")["handle"]
    assert_equal "Almanac", yaml("themes/almanac/theme.yml")["name"]
    assert_equal "@nibble-theme/almanac", JSON.parse(@root.join("themes/almanac/package.json").read)["name"]
    assert_equal "<h1>home</h1>", @root.join("themes/almanac/views/home.vue").read, "it has to start working, not empty"
    assert_equal "crumbs", yaml("themes/crumbs/theme.yml")["handle"], "ours is what it was copied from, not moved"
  end

  test "generating a theme names it as the site's, so nobody edits ours to see a change" do
    starter
    @root.join("config").mkpath
    @root.join("config/nibble.yml").write("default: &default\n  load_defaults: \"0.2.0\"\n  theme: crumbs\n")

    written = Nibble::Generate.theme("almanac", root: @root)

    assert_match "theme: almanac", @root.join("config/nibble.yml").read
    assert_match "load_defaults", @root.join("config/nibble.yml").read, "only the line naming the theme is touched"
    assert_match "config/nibble.yml", written.sole.note
  end

  test "a site with no settings file is told how to switch to it rather than left guessing" do
    starter

    assert_match "NIBBLE_THEME=almanac", Nibble::Generate.theme("almanac", root: @root).sole.note
  end

  test "an existing theme is never written over" do
    starter

    Nibble::Generate.theme("almanac", root: @root)
    error = assert_raises(Nibble::Generate::Refused) { Nibble::Generate.theme("almanac", root: @root) }

    assert_match "already exists", error.message
  end

  private

  def starter
    views = @root.join("themes", Nibble::DEFAULT_THEME, "views")
    views.mkpath
    views.join("home.vue").write("<h1>home</h1>")
    @root.join("themes", Nibble::DEFAULT_THEME, "theme.yml").write({ "name" => "Crumbs", "handle" => "crumbs" }.to_yaml)
    @root.join("themes", Nibble::DEFAULT_THEME, "package.json").write(%({"name":"@nibble-theme/crumbs","private":true}))
  end
end
