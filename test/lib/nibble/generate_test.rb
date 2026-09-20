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
end
