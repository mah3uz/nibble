require "test_helper"

class Nibble::ContentMigrationsTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def migration(name, *operations)
    path = @nibble_themes.join("records/schema/migrations/#{name}.yml")
    path.dirname.mkpath
    path.write({ "operations" => operations }.to_yaml)
  end

  def legacy(entry, values)
    entry.update_columns(data: entry.data.merge(values))
    entry
  end

  def run_migrations(dry_run: false)
    results = Nibble::ContentMigrations.run(dry_run:)
    Nibble::Events.dispatch_pending
    results
  end

  test "a renamed field takes its data with it, so nothing looks lost after the schema changes" do
    article = legacy(create_entry("articles", { "title" => "One" }), "intro" => "Old text")
    migration("2026_10_01_rename_intro", { "rename_field" => { "collection" => "articles", "from" => "intro", "to" => "summary" } })

    results = run_migrations

    assert_equal "Old text", article.reload.data["summary"]
    assert_not article.data.key?("intro")
    assert_equal [ [ "rename articles.intro to summary", 1 ] ], results.first.counts
    assert_equal "import", article.revisions.last.kind
  end

  test "a pending draft is migrated too, so publishing it later can't bring the old field back" do
    article = publish_entry(create_entry("articles", { "title" => "Live" }))
    lifecycle(article.reload, :save, { "title" => "Edited" })
    article.draft.update_columns(data: article.draft.data.merge("intro" => "Draft text"))
    migration("2026_10_01_rename_intro", { "rename_field" => { "collection" => "articles", "from" => "intro", "to" => "summary" } })

    run_migrations

    assert_equal "Draft text", article.reload.draft.data["summary"]
    assert_not article.draft.data.key?("intro")
  end

  test "a rename never overwrites a value already in the new field" do
    article = legacy(create_entry("articles", { "title" => "One", "summary" => "Kept" }), "intro" => "Old")
    migration("2026_10_01_rename_intro", { "rename_field" => { "collection" => "articles", "from" => "intro", "to" => "summary" } })

    run_migrations

    assert_equal "Kept", article.reload.data["summary"]
  end

  test "a migration runs once, however many times the task does" do
    legacy(create_entry("articles", { "title" => "One" }), "intro" => "Old")
    migration("2026_10_01_rename_intro", { "rename_field" => { "collection" => "articles", "from" => "intro", "to" => "summary" } })

    run_migrations
    revisions = Nibble::Records::Revision.count

    assert_empty run_migrations
    assert_equal revisions, Nibble::Records::Revision.count
  end

  test "a default fills only the entries that have no value" do
    blank = create_entry("articles", { "title" => "Blank" })
    set = create_entry("articles", { "title" => "Set", "summary" => "Mine" })
    migration("2026_10_02_default_summary", { "set_default" => { "collection" => "articles", "field" => "summary", "value" => "None yet" } })

    results = run_migrations

    assert_equal [ "None yet", "Mine" ], [ blank.reload.data["summary"], set.reload.data["summary"] ]
    assert_equal 1, results.first.counts.first.last
  end

  test "a plain text field becomes real taxonomy terms, reusing the ones that exist" do
    existing = create_term("Design")
    first = legacy(create_entry("articles", { "title" => "One" }), "category_name" => "Design")
    second = legacy(create_entry("articles", { "title" => "Two" }), "category_name" => [ "Design", "Colour" ])
    migration("2026_10_03_categories", { "move_to_taxonomy" => { "collection" => "articles", "field" => "category_name", "taxonomy" => "tags" } })

    run_migrations

    colour = Nibble::Records::Term.find_by!(taxonomy: "tags", slug: "colour")
    assert_equal [ existing.id.to_s ], first.reload.data["tags"]
    assert_equal [ existing.id.to_s, colour.id.to_s ], second.reload.data["tags"]
    assert_not second.data.key?("category_name")
    assert_equal 2, Nibble::Records::Term.where(taxonomy: "tags").count, "Design wasn't created twice"
    assert Nibble::Records::Relation.exists?(source_id: second.id, target_type: "term", target_id: colour.id), "relations follow"
  end

  test "entries can be moved to another blueprint" do
    theme = @nibble_themes.join("records/schema")
    theme.join("blueprints/collections/articles/feature.yml").write({ "title" => "Feature", "tabs" => { "main" => { "sections" => [
      { "fields" => [ { "handle" => "title", "field" => { "type" => "text" } } ] } ] } } }.to_yaml)
    collection = YAML.safe_load_file(theme.join("collections/articles.yml"))
    theme.join("collections/articles.yml").write(collection.merge("blueprints" => %w[article feature]).to_yaml)
    Nibble.reset_schema!
    article = create_entry("articles", { "title" => "One" })
    migration("2026_10_04_features", { "change_blueprint" => { "collection" => "articles", "from" => "article", "to" => "feature" } })

    run_migrations

    assert_equal "feature", article.reload.blueprint
  end

  test "a dry run counts what would change and changes nothing" do
    article = legacy(create_entry("articles", { "title" => "One" }), "intro" => "Old")
    migration("2026_10_01_rename_intro", { "rename_field" => { "collection" => "articles", "from" => "intro", "to" => "summary" } })

    results = run_migrations(dry_run: true)

    assert_equal 1, results.first.counts.first.last
    assert_equal "Old", article.reload.data["intro"]
    assert_equal 0, Nibble::Records::ContentMigration.count, "a dry run isn't recorded as run"
  end

  test "one bad migration stops the lot before anything is written" do
    article = legacy(create_entry("articles", { "title" => "One" }), "intro" => "Old")
    migration("2026_10_01_rename_intro", { "rename_field" => { "collection" => "articles", "from" => "intro", "to" => "summary" } })
    migration("2026_10_02_broken", { "rename_field" => { "collection" => "nowhere", "from" => "a", "to" => "b" } })

    error = assert_raises(Nibble::Error) { run_migrations }

    assert_match "2026_10_02_broken.yml: operations.0", error.message
    assert_equal "Old", article.reload.data["intro"]
  end

  test "a removed collection's records can be cleared, which nibble:check otherwise reports with nothing to run" do
    doc = create_entry("docs", { "title" => "Stranded" })
    kept = create_entry("articles", { "title" => "Still here" })
    Nibble::Revisions.write(doc, :import, snapshot: doc.snapshot, actor: nil, message: "before")
    @nibble_themes.join("records/schema/collections/docs.yml").delete
    FileUtils.rm_rf(@nibble_themes.join("records/schema/blueprints/collections/docs"))
    Nibble.reset_schema!

    migration("2026_10_01_drop_docs", { "delete_collection" => { "collection" => "docs" } })
    run_migrations

    assert_empty Nibble::Records::Entry.where(collection: "docs")
    assert_empty Nibble::Records::Revision.where(record_type: "Nibble::Records::Entry", record_id: doc.id)
    assert_equal "Still here", kept.reload.title, "only the removed collection's records go"
  end

  # The handle is a column on every record, so a site that renames a collection in its schema strands all of
  # them; without this there is no way to bring them across, and the site refuses to boot.
  test "a renamed collection's records are carried over to the new handle" do
    doc = create_entry("docs", { "title" => "Carried" })
    kept = create_entry("articles", { "title" => "Still here" })
    uri = doc.uri
    @nibble_themes.join("records/schema/collections/docs.yml").delete
    FileUtils.rm_rf(@nibble_themes.join("records/schema/blueprints/collections/docs"))
    Nibble.reset_schema!

    migration("2026_10_01_rename_docs", { "rename_collection" => { "from" => "docs", "to" => "articles" } })
    run_migrations

    assert_empty Nibble::Records::Entry.where(collection: "docs")
    assert_equal "articles", doc.reload.collection
    assert_equal "Carried", doc.title, "a rename moves the handle and nothing else"
    assert_equal uri, doc.uri, "addresses come from the route, so a rename is not a move"
    assert_equal "articles", kept.reload.collection
  end

  test "a collection still in the schema is never renamed away from" do
    create_entry("articles", { "title" => "One" })
    migration("2026_10_01_rename_live", { "rename_collection" => { "from" => "articles", "to" => "docs" } })

    error = assert_raises(Nibble::Error) { run_migrations }

    assert_match "still in the schema", error.message
    assert_equal 1, Nibble::Records::Entry.where(collection: "articles").count
  end

  test "a rename to a collection the schema does not have is refused" do
    @nibble_themes.join("records/schema/collections/docs.yml").delete
    FileUtils.rm_rf(@nibble_themes.join("records/schema/blueprints/collections/docs"))
    Nibble.reset_schema!
    migration("2026_10_01_rename_nowhere", { "rename_collection" => { "from" => "docs", "to" => "nowhere" } })

    error = assert_raises(Nibble::Error) { run_migrations }

    assert_match "isn't in the schema", error.message
  end

  test "a collection still in the schema is never deleted by a migration" do
    create_entry("articles", { "title" => "One" })
    migration("2026_10_01_drop_articles", { "delete_collection" => { "collection" => "articles" } })

    error = assert_raises(Nibble::Error) { run_migrations }

    assert_match "still in the schema", error.message
    assert_equal 1, Nibble::Records::Entry.where(collection: "articles").count
  end

  test "migrations run in date order across layers" do
    migration("2026_10_02_second", { "set_default" => { "collection" => "articles", "field" => "summary", "value" => "b" } })
    migration("2026_10_01_first", { "set_default" => { "collection" => "articles", "field" => "summary", "value" => "a" } })

    assert_equal %w[theme/2026_10_01_first theme/2026_10_02_second], Nibble::ContentMigrations.pending.map(&:name)
  end

  test "a site's own migrations belong to that site, not to whatever runs these tests" do
    site = Rails.root.join("schema/migrations")
    site.mkpath
    path = site.join("2026_10_03_a_site_of_its_own.yml")
    path.write({ "operations" => [ { "delete_collection" => { "collection" => "gone" } } ] }.to_yaml)

    names = Nibble::ContentMigrations.pending.map(&:name)

    assert_empty names, "the schema layers are configured, so a real site's migrations cannot reach a fixture"
  ensure
    path&.delete
  end
end
