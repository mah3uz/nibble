require "test_helper"

class Nibble::PrepareTest < ActiveSupport::TestCase
  setup do
    @steps = []
    @themes = Pathname(Dir.mktmpdir("nibble-prepare"))
    FileUtils.cp_r(Nibble.core_root.join("themes/crumbs"), @themes.join("crumbs"))
    Nibble.config = Nibble::Config.new(Nibble.config_values.merge("theme" => "crumbs"),
      themes_path: @themes, site_schema_path: @themes.join("no_site_schema"), types_path: @themes.join("types.d.ts"))
    Nibble.reset_schema!
    Nibble::TypeGenerator.write!
  end

  teardown do
    Nibble.config = nil
    Nibble.reset_schema!
    FileUtils.rm_rf(@themes)
  end

  def create_post(title)
    result = Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts"), :create, { "title" => title })
    assert result.ok?, result.errors.inspect
    result.record
  end

  def prepare(**options) = Nibble::Prepare.run(database: -> { @steps << :database }, **options)

  def migration(name, *operations)
    path = @themes.join("crumbs/schema/migrations/#{name}.yml")
    path.dirname.mkpath
    path.write({ "operations" => operations }.to_yaml)
  end

  def strand(entry, values) = entry.tap { entry.update_columns(data: entry.data.merge(values)) }

  test "preparing migrates the database, then content, then records the schema" do
    article = strand(create_post("One"), "intro" => "Old")
    migration("2026_10_01_rename", { "rename_field" => { "collection" => "posts", "from" => "intro", "to" => "excerpt" } })

    result = prepare

    assert_equal [ :database ], @steps
    assert_equal [ "theme/2026_10_01_rename" ], result.migrations.map(&:name)
    assert_equal "Old", article.reload.data["excerpt"]
    assert result.snapshot, "the schema this release runs on is recorded for the next type check"
  end

  test "a theme built for another major version stops preparing before anything is touched" do
    manifest = @themes.join("crumbs/theme.yml")
    manifest.write(YAML.safe_load_file(manifest).merge("nibble" => "^2").to_yaml)
    migration("2026_10_01_default", { "set_default" => { "collection" => "posts", "field" => "excerpt", "value" => "x" } })

    error = assert_raises(Nibble::Prepare::Stopped) { prepare }

    assert_match "asks for nibble \"^2\"", error.message
    assert_empty @steps, "the database wasn't touched"
    assert_equal 0, Nibble::Records::ContentMigration.count
  end

  test "data the new schema would strand stops preparing before any content migration runs" do
    strand(create_post("One"), "legacy" => "Unmigrated")
    migration("2026_10_01_default", { "set_default" => { "collection" => "posts", "field" => "excerpt", "value" => "x" } })

    error = assert_raises(Nibble::Prepare::Stopped) { prepare }

    assert_match "before content migrations", error.message
    assert_match "legacy was removed", error.message
    assert_equal 0, Nibble::Records::ContentMigration.count, "nothing half-done"
    assert_equal 0, Nibble::Records::SchemaSnapshot.count
  end

  test "--allow-data-loss lets it through, reporting what's left behind" do
    strand(create_post("One"), "legacy" => "Unmigrated")

    result = prepare(allow_data_loss: true)

    assert(result.warnings.any? { |warning| warning.include?("legacy was removed") })
    assert result.snapshot
  end

  test "running it again is harmless" do
    prepare
    second = prepare

    assert_empty second.migrations
    assert_not second.snapshot
  end

  test "preparing writes db/schema.rb when the site has none, since ours is no longer shipped" do
    dumped = false

    Nibble::Prepare.run(database: -> { }, schema_file: @themes.join("no-schema.rb"), schema_dump: -> { dumped = true })

    assert dumped, "migrating alone does not write it when there is nothing left to migrate"
  end

  test "a site's own db/schema.rb is left exactly as it is" do
    theirs = @themes.join("schema.rb")
    theirs.write("# theirs")

    Nibble::Prepare.run(database: -> { }, schema_file: theirs, schema_dump: -> { flunk "never overwrite a site's own" })

    assert_equal "# theirs", theirs.read
  end

  # Every deploy boots through nibble:prepare, and a page written as a file publishes no events, so this is the only
  # thing that makes a newly deployed article searchable.
  test "preparing indexes pages written as files, with no manual rebuild" do
    site = @themes.join("site_schema")
    { "collections/help.yml" => { "schema" => 1, "title" => "Help", "route" => "/help/{slug}", "blueprints" => [ "article" ], "files" => "help" },
      "blueprints/collections/help/article.yml" => { "schema" => 1, "title" => "Article",
        "tabs" => { "main" => { "sections" => [ { "fields" => [ { "handle" => "body", "field" => { "type" => "markdown" } } ] } ] } } },
      "search.yml" => { "schema" => 1, "indexes" => { "site" => { "collections" => %w[pages posts help] } } } }.each do |path, data|
      site.join(path).dirname.mkpath
      site.join(path).write(data.to_yaml)
    end
    content = @themes.join("content")
    content.join("help").mkpath
    content.join("help/index.md").write("---\nid: help\ntitle: Help\n---\n\nStart here.\n")
    content.join("help/import.md").write("---\nid: import\ntitle: Importing clients\n---\n\nBring your spreadsheet.\n")
    Nibble.config = Nibble::Config.new(Nibble.config_values.merge("theme" => "crumbs"),
      themes_path: @themes, site_schema_path: site, content_path: content, published_path: @themes.join("published"),
      types_path: @themes.join("types.d.ts"))
    Nibble.reset_schema!
    Nibble::TypeGenerator.write!

    prepare
    hits = Nibble::Search.search("site", "spreadsheet", locale: "en").hits
    assert_equal [ "import" ], hits.map(&:record_id)
  end
end
