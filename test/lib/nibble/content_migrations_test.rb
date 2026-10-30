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

  def global_schema(handle, fields)
    @nibble_themes.join("records/schema/globals").mkpath
    @nibble_themes.join("records/schema/globals/#{handle}.yml").write({ "title" => handle.capitalize, "blueprint" => { "title" => handle.capitalize,
      "tabs" => { "main" => { "sections" => [ { "fields" => fields.map { |field, type| { "handle" => field, "field" => { "type" => type } } } } ] } } } }.to_yaml)
    Nibble.reset_schema!
  end

  def save_global(handle, locale, values)
    record = Nibble::Records::GlobalSet.find_or_initialize_by(handle:, locale:)
    assert lifecycle(record, :save, values).ok?
    record.reload
  end

  def in_two_locales
    Nibble.config = Nibble::Config.new({ "theme" => "records", "url" => "https://example.com", "reserved_paths" => [ "/cp" ],
                                         "locales" => [ { "code" => "en", "default" => true }, { "code" => "fr", "url_prefix" => "/fr" } ] },
      themes_path: @nibble_themes, site_schema_path: @nibble_themes.join("site_schema"), agents_path: @nibble_themes.join("agents"))
    Nibble.reset_schema!
    yield
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
    Nibble::Records::Draft.create!(record: doc, data: { "title" => "Unpublished" })
    Nibble::Records::Relation.create!(source: doc, target_type: "asset", target_id: 1, field: "image", locale: "en")
    Nibble::Records::Relation.create!(source: kept, target_type: "entry", target_id: doc.id, field: "related", locale: "en")
    role = Nibble::Role.create!(handle: "specific", title: "Specific", abilities: %w[entries.docs.edit entries.*.view])
    @nibble_themes.join("records/schema/collections/docs.yml").delete
    FileUtils.rm_rf(@nibble_themes.join("records/schema/blueprints/collections/docs"))
    Nibble.reset_schema!

    migration("2026_10_01_drop_docs", { "delete_collection" => { "collection" => "docs" } })
    run_migrations

    assert_empty Nibble::Records::Entry.where(collection: "docs")
    assert_empty Nibble::Records::Revision.where(record_type: "entry", record_id: doc.id)
    assert_empty Nibble::Records::Draft.where(record_type: "entry", record_id: doc.id)
    assert_empty Nibble::Records::Relation.where(source_type: "entry", source_id: doc.id)
    assert_empty Nibble::Records::Relation.where(target_type: "entry", target_id: doc.id),
                 "a relation left pointing at a deleted entry would resurface under a reused id"
    assert_equal "Still here", kept.reload.title, "only the removed collection's records go"
    assert_equal %w[entries.*.view], role.reload.abilities, "a collection given the handle later starts with nobody holding it"
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

  test "a global's field is renamed in every locale, so no translation is stranded under the old name" do
    global_schema("contact", "phone" => "text", "telephone" => "text")
    in_two_locales do
      english = save_global("contact", "en", "phone" => "555 0100")
      french = save_global("contact", "fr", "phone" => "01 23 45")
      global_schema("contact", "telephone" => "text")
      migration("2026_10_05_rename_phone", { "rename_field" => { "global" => "contact", "from" => "phone", "to" => "telephone" } })

      assert_empty Nibble::Drift.issues, "the pending rename answers the removed field"

      results = run_migrations

      assert_equal [ [ "rename contact.phone to telephone", 2 ] ], results.first.counts
      assert_equal [ "555 0100", "01 23 45" ], [ english.reload.data["telephone"], french.reload.data["telephone"] ]
      assert_not english.data.key?("phone")
      assert_equal "import", english.revisions.last.kind
      assert_equal "555 0100", english.revisions.last.data["telephone"]
      assert_empty Nibble::Drift.issues
    end
  end

  test "a global's default fills only the locales where it is empty" do
    global_schema("contact", "phone" => "text", "hours" => "text")
    in_two_locales do
      blank = save_global("contact", "en", "phone" => "555 0100")
      set = save_global("contact", "fr", "hours" => "9–5")
      migration("2026_10_06_hours", { "set_default" => { "global" => "contact", "field" => "hours", "value" => "By appointment" } })

      results = run_migrations

      assert_equal [ "By appointment", "9–5" ], [ blank.reload.data["hours"], set.reload.data["hours"] ]
      assert_equal 1, results.first.counts.first.last
    end
  end

  def move_rating(name, **options)
    migration(name, { "move_field" => { "from" => { "global" => "listing", "field" => "google_rating" },
                                        "to" => { "global" => "social", "field" => "rating" } }.merge(options.stringify_keys) })
  end

  # Overwriting would destroy what an editor already put in the new place, with no revision of the global it came
  # from to say why; leaving it keeps both values and keeps nibble:check refusing until someone decides.
  test "a move never overwrites a value already in the destination, and reports the record it left" do
    global_schema("listing", "google_rating" => "integer", "name" => "text")
    global_schema("social", "rating" => "integer")
    in_two_locales do
      english = save_global("listing", "en", "google_rating" => 4)
      french = save_global("listing", "fr", "google_rating" => 5)
      kept = save_global("social", "en", "rating" => 3)
      global_schema("listing", "name" => "text")
      move_rating("2026_10_07_move_rating")

      results = run_migrations

      label, count = results.first.counts.sole
      assert_equal "move listing.google_rating to social.rating, leaving global #{english.id} (en) where rating already holds a value", label
      assert_equal 1, count
      assert_equal 3, kept.reload.data["rating"]
      assert_equal 4, english.reload.data["google_rating"], "the value it couldn't move stays where it was"
      assert_equal 5, Nibble::Records::GlobalSet.find_by!(handle: "social", locale: "fr").data["rating"], "a locale with no social set yet gets one"
      assert_not french.reload.data.key?("google_rating")
      assert_equal [ "globals/listing: google_rating was removed and 1 record still hold it; #{Nibble::Drift::HINT}" ],
                   Nibble::Drift.issues.map { |issue| "#{issue.source}: #{issue.message}" }

      move_rating("2026_10_08_overwrite_rating", overwrite: true)
      run_migrations

      assert_equal 4, kept.reload.data["rating"]
      assert_not english.reload.data.key?("google_rating")
      assert_equal 3, kept.revisions.reverse_order.second.data["rating"], "the value it replaced is still in the history"
      assert_empty Nibble::Drift.issues
    end
  end

  test "moving a value again changes nothing, so a repeated operation is harmless" do
    global_schema("listing", "google_rating" => "integer")
    global_schema("social", "rating" => "integer")
    save_global("listing", "en", "google_rating" => 4)
    move_rating("2026_10_07_move_rating")
    run_migrations
    revisions = Nibble::Records::Revision.count

    move_rating("2026_10_08_move_rating_again")
    results = run_migrations

    assert_equal 0, results.first.counts.sole.last
    assert_equal revisions, Nibble::Records::Revision.count
    assert_equal 4, Nibble::Records::GlobalSet.find_by!(handle: "social").data["rating"]
  end

  test "a dry run of a move counts it and moves nothing" do
    global_schema("listing", "google_rating" => "integer")
    global_schema("social", "rating" => "integer")
    listing = save_global("listing", "en", "google_rating" => 4)
    move_rating("2026_10_07_move_rating")

    results = run_migrations(dry_run: true)

    assert_equal [ [ "move listing.google_rating to social.rating", 1 ] ], results.first.counts
    assert_equal 4, listing.reload.data["google_rating"]
    assert_nil Nibble::Records::GlobalSet.find_by(handle: "social")
  end

  test "a value moves between the fields of one collection, in its draft too" do
    article = publish_entry(legacy(create_entry("articles", { "title" => "Live" }), "intro" => "Old"))
    lifecycle(article.reload, :save, { "title" => "Edited" })
    article.draft.update_columns(data: article.draft.data.merge("intro" => "Draft"))
    migration("2026_10_07_move_intro", { "move_field" => { "from" => { "collection" => "articles", "field" => "intro" },
                                                           "to" => { "collection" => "articles", "field" => "summary" } } })

    run_migrations

    assert_equal [ "Old", "Draft" ], [ article.reload.data["summary"], article.draft.data["summary"] ]
    assert_not article.data.key?("intro")
    assert_not article.draft.data.key?("intro")
  end

  test "a move is refused when its two ends couldn't hold the same value" do
    global_schema("listing", "google_rating" => "integer")
    global_schema("social", "rating" => "integer", "handle" => "text")
    Nibble::Drift.record_snapshot!
    global_schema("listing", {})
    refusals = {
      { "global" => "social", "field" => "handle" } => "listing.google_rating is integer and social.handle is text",
      { "global" => "social", "field" => "stars" } => "stars isn't a field of social",
      { "collection" => "articles", "field" => "summary" } => "moves between the fields of one collection or taxonomy, or between globals"
    }

    refusals.each_with_index do |(to, message), index|
      FileUtils.rm_rf(@nibble_themes.join("records/schema/migrations"))
      migration("2026_10_0#{index}_move", { "move_field" => { "from" => { "global" => "listing", "field" => "google_rating" }, "to" => to } })

      assert_match message, assert_raises(Nibble::Error) { run_migrations }.message
    end
  end

  test "a removed field's values are cleared from entries, drafts and globals, so nibble:check passes" do
    global_schema("listing", "google_rating" => "integer", "name" => "text")
    listing = save_global("listing", "en", "google_rating" => 4, "name" => "Cafe")
    article = publish_entry(legacy(create_entry("articles", { "title" => "Live" }), "intro" => "Old"))
    lifecycle(article.reload, :save, { "title" => "Edited" })
    article.draft.update_columns(data: article.draft.data.merge("intro" => "Draft"))
    global_schema("listing", "name" => "text")
    assert_equal 2, Nibble::Drift.issues.size

    migration("2026_10_07_remove", { "remove_field" => { "global" => "listing", "field" => "google_rating" } },
              { "remove_field" => { "collection" => "articles", "field" => "intro" } })
    results = run_migrations

    assert_equal [ [ "remove listing.google_rating", 1 ], [ "remove articles.intro", 1 ] ], results.first.counts
    assert_equal({ "name" => "Cafe" }, listing.reload.data)
    assert_not article.reload.data.key?("intro")
    assert_not article.draft.data.key?("intro")
    assert_equal [ 4, nil ], listing.revisions.last(2).map { |revision| revision.data["google_rating"] }, "the history keeps the value to restore"
    assert_equal "remove listing.google_rating", listing.revisions.last.message
    assert_empty Nibble::Drift.issues

    migration("2026_10_08_remove_again", { "remove_field" => { "global" => "listing", "field" => "google_rating" } })
    assert_equal 0, run_migrations.first.counts.sole.last
  end

  test "a field still in the schema is never removed by a migration" do
    article = create_entry("articles", { "title" => "One", "summary" => "Kept" })
    migration("2026_10_07_remove", { "remove_field" => { "collection" => "articles", "field" => "summary" } })

    error = assert_raises(Nibble::Error) { run_migrations }

    assert_match "summary is still a field of articles", error.message
    assert_equal "Kept", article.reload.data["summary"]
  end

  # A draft keeps an entry's columns beside its fields, so removing one by that name would empty the draft's status.
  test "a draft's columns are never removed as though they were fields" do
    migration("2026_10_07_remove", { "remove_field" => { "collection" => "articles", "field" => "status" } })

    assert_match "status isn't a field that can be removed", assert_raises(Nibble::Error) { run_migrations }.message
  end

  test "migrations run in date order across layers" do
    migration("2026_10_02_second", { "set_default" => { "collection" => "articles", "field" => "summary", "value" => "b" } })
    migration("2026_10_01_first", { "set_default" => { "collection" => "articles", "field" => "summary", "value" => "a" } })

    assert_equal %w[theme/2026_10_01_first theme/2026_10_02_second], Nibble::ContentMigrations.pending.map(&:name)
  end

  def move_schema(kind, from, to)
    folder = @nibble_themes.join("records/schema/#{kind}")
    folder.join("#{from}.yml").rename(folder.join("#{to}.yml"))
    blueprints = @nibble_themes.join("records/schema/blueprints/#{kind}/#{from}")
    blueprints.rename(blueprints.dirname.join(to)) if blueprints.exist?
    Nibble.reset_schema!
  end

  def drop_schema(kind, handle)
    @nibble_themes.join("records/schema/#{kind}/#{handle}.yml").delete
    FileUtils.rm_rf(@nibble_themes.join("records/schema/blueprints/#{kind}/#{handle}"))
    Nibble.reset_schema!
  end

  def save_menu(locale, tree)
    record = Nibble::Records::NavigationTree.find_or_initialize_by(handle: "docs_menu", locale:)
    assert lifecycle(record, :save, "tree" => tree).ok?
    record.reload
  end

  # One person holding the abilities through a role, and an app they connected with the same abilities granted.
  def delegate(*abilities)
    role = Nibble::Role.create!(handle: "specific", title: "Specific", abilities: abilities + %w[apps.connect])
    users(:author).roles = [ role ]
    Nibble::Grant.create!(user: users(:author), oauth_client: Nibble::OauthClient.cli, kind: "app", name: "Claude", preset: "custom", abilities:)
    Nibble::AgentAccess.update!(enabled: true, areas: { "navigation" => { "read" => true, "write" => true }, "globals" => { "read" => true, "write" => true } })
  end

  def person_and_app_can?(ability)
    user = Nibble::User.find(users(:author).id)
    grant = Nibble::Grant.find_by!(name: "Claude")
    [ nil, grant ].map { |held| Nibble::Policy.can?(Nibble::Principal.new(user:, grant: held), ability) }
  end

  def run_again
    Nibble::Records::ContentMigration.delete_all
    run_migrations
  end

  test "a renamed menu keeps every item in every locale, and whoever could edit it still can" do
    in_two_locales do
      doc = create_entry("docs", { "title" => "Guide" })
      english = save_menu("en", [ { "type" => "entry", "id" => doc.id, "children" => [ { "type" => "url", "title" => "Home", "url" => "/" } ] } ])
      french = save_menu("fr", [ { "type" => "url", "title" => "Accueil", "url" => "/fr" } ])
      delegate("navigation.docs_menu.edit")
      move_schema("navigation", "docs_menu", "guide_menu")
      migration("2026_10_30_rename_menu", { "rename_navigation" => { "from" => "docs_menu", "to" => "guide_menu" } })
      editor = roles(:editor).abilities

      results = run_migrations

      assert_equal [ [ "rename navigation docs_menu to guide_menu", 2 ] ], results.first.counts
      assert_empty Nibble::Records::NavigationTree.where(handle: "docs_menu")
      assert_equal [ "guide_menu", english.tree ], [ english.reload.handle, english.tree ]
      assert_equal [ "guide_menu", french.tree ], [ french.reload.handle, french.tree ]
      assert english.revisions.any?, "the id is kept, so the menu's history follows it"
      assert_equal [ doc.id ], Nibble::Records::Relation.where(source_type: "navigation", source_id: english.id).pluck(:target_id)
      assert_equal [ true, true ], person_and_app_can?("navigation.guide_menu.edit")
      assert_equal editor, roles(:editor).reload.abilities, "a wildcard already covers the new handle and is left alone"

      run_again

      assert_equal [ english.tree, french.tree ], [ english.reload.tree, french.reload.tree ]
      assert_equal %w[navigation.guide_menu.edit apps.connect], Nibble::Role.find_by!(handle: "specific").abilities
      assert_equal %w[navigation.guide_menu.edit], Nibble::Grant.find_by!(name: "Claude").abilities
    end
  end

  test "a rename leaves a locale where the new menu already has one, instead of overwriting it" do
    in_two_locales do
      old = save_menu("en", [ { "type" => "url", "title" => "Old", "url" => "/old" } ])
      moved = save_menu("fr", [ { "type" => "url", "title" => "Vieux", "url" => "/fr/old" } ])
      move_schema("navigation", "docs_menu", "guide_menu")
      kept = Nibble::Records::NavigationTree.create!(handle: "guide_menu", locale: "en", tree: [ { "type" => "url", "title" => "New", "url" => "/new" } ])
      migration("2026_10_30_rename_menu", { "rename_navigation" => { "from" => "docs_menu", "to" => "guide_menu" } })

      results = run_migrations

      assert_equal [ [ "rename navigation docs_menu to guide_menu, leaving en where guide_menu already has one", 1 ] ], results.first.counts
      assert_equal [ "docs_menu", "Old" ], [ old.reload.handle, old.tree.first["title"] ]
      assert_equal [ "guide_menu", "New" ], [ kept.reload.handle, kept.tree.first["title"] ]
      assert_equal "guide_menu", moved.reload.handle
    end
  end

  test "a deleted menu leaves no rows, history, drafts, relations or permissions behind" do
    doc = create_entry("docs", { "title" => "Guide" })
    menu = save_menu("en", [ { "type" => "entry", "id" => doc.id } ])
    Nibble::Records::Draft.create!(record: menu, data: { "tree" => [] })
    delegate("navigation.docs_menu.edit", "navigation.*.view")
    drop_schema("navigation", "docs_menu")
    migration("2026_10_30_drop_menu", { "delete_navigation" => { "navigation" => "docs_menu" } })

    assert_equal [ [ "delete navigation docs_menu", 1 ] ], run_migrations.first.counts

    assert_empty Nibble::Records::NavigationTree.where(handle: "docs_menu")
    assert_empty Nibble::Records::Revision.where(record_type: "navigation", record_id: menu.id)
    assert_empty Nibble::Records::Draft.where(record_type: "navigation", record_id: menu.id)
    assert_empty Nibble::Records::Relation.where(source_type: "navigation", source_id: menu.id)
    assert_equal %w[navigation.*.view apps.connect], Nibble::Role.find_by!(handle: "specific").abilities,
                 "a permission left on the handle would come back with any menu given that name later"
    assert_equal %w[navigation.*.view], Nibble::Grant.find_by!(name: "Claude").abilities
    assert_equal "Guide", doc.reload.title

    assert_equal [ [ "delete navigation docs_menu", 0 ] ], run_again.first.counts
  end

  test "a renamed global set keeps its values in every locale, and whoever could edit it still can" do
    global_schema("contact", "phone" => "text")
    in_two_locales do
      english = save_global("contact", "en", "phone" => "555 0100")
      french = save_global("contact", "fr", "phone" => "01 23 45")
      delegate("globals.contact.edit")
      @nibble_themes.join("records/schema/globals/contact.yml").delete
      global_schema("details", "phone" => "text")
      migration("2026_10_30_rename_contact", { "rename_global" => { "from" => "contact", "to" => "details" } })

      assert_empty Nibble::Drift.issues, "the pending rename answers the removed global set"

      assert_equal [ [ "rename global contact to details", 2 ] ], run_migrations.first.counts
      assert_equal [ "details", "555 0100" ], [ english.reload.handle, english.data["phone"] ]
      assert_equal [ "details", "01 23 45" ], [ french.reload.handle, french.data["phone"] ]
      assert english.revisions.any?
      assert_equal [ true, true ], person_and_app_can?("globals.details.edit")
      assert_empty Nibble::Drift.issues

      assert_equal [ [ "rename global contact to details", 0 ] ], run_again.first.counts
      assert_equal [ true, true ], person_and_app_can?("globals.details.edit")
    end
  end

  test "a deleted global set leaves no rows, history, relations or permissions behind" do
    global_schema("contact", "phone" => "text")
    global_schema("hours", "open" => "text")
    contact = save_global("contact", "en", "phone" => "555 0100")
    hours = save_global("hours", "en", "open" => "9–5")
    article = create_entry("articles", { "title" => "Linked" })
    Nibble::Records::Relation.create!(source: article, target_type: "global", target_id: contact.id, field: "related", locale: "en")
    delegate("globals.contact.edit")
    drop_schema("globals", "contact")
    migration("2026_10_30_drop_contact", { "delete_global" => { "global" => "contact" } })

    run_migrations

    assert_empty Nibble::Records::GlobalSet.where(handle: "contact")
    assert_empty Nibble::Records::Revision.where(record_type: "global", record_id: contact.id)
    assert_empty Nibble::Records::Relation.where(target_type: "global", target_id: contact.id)
    assert_equal %w[apps.connect], Nibble::Role.find_by!(handle: "specific").abilities
    assert_equal "9–5", hours.reload.data["open"], "only the named set goes"
    assert_empty Nibble::Drift.issues
  end

  test "a menu or global set still in the schema is never renamed away from or deleted, nor renamed to one it lacks" do
    save_menu("en", [ { "type" => "url", "title" => "Home", "url" => "/" } ])
    refusals = {
      { "rename_navigation" => { "from" => "docs_menu", "to" => "main" } } => "navigation 'docs_menu' is still in the schema",
      { "delete_navigation" => { "navigation" => "docs_menu" } } => "navigation 'docs_menu' is still in the schema",
      { "rename_navigation" => { "from" => "gone", "to" => "nowhere" } } => "navigation 'nowhere' isn't in the schema",
      { "rename_global" => { "from" => "site", "to" => "seo" } } => "global set 'site' is still in the schema",
      { "delete_global" => { "global" => "integrations" } } => "global set 'integrations' is still in the schema",
      { "rename_global" => { "from" => "gone", "to" => "nowhere" } } => "global set 'nowhere' isn't in the schema",
      { "delete_global" => {} } => "only deletes a global set"
    }

    refusals.each do |operation, message|
      migration("2026_10_30_refused", operation)
      assert_match message, assert_raises(Nibble::Error) { run_migrations }.message
    end
    assert Nibble::Records::NavigationTree.exists?(handle: "docs_menu")
  end

  # Abilities name the handle, so without this a rename leaves editors and apps locked out of the collection.
  test "a renamed collection carries its permissions and its agent access settings" do
    delegate("entries.docs.edit", "workflow.approve.docs")
    Nibble::AgentAccess.update!(areas: { "entries.docs" => { "read" => true, "write" => false } })
    move_schema("collections", "docs", "guides")
    migration("2026_10_30_rename_docs", { "rename_collection" => { "from" => "docs", "to" => "guides" } })

    run_migrations

    assert_equal [ true, false ], person_and_app_can?("entries.guides.edit"),
                 "an administrator who stopped apps writing to the collection still has them stopped under its new handle"
    assert_equal [ true, false ], person_and_app_can?("workflow.approve.guides")
    assert_equal %w[entries.guides.edit workflow.approve.guides], Nibble::Grant.find_by!(name: "Claude").abilities
    assert_nil Nibble::AgentAccess.settings.dig("areas", "entries.docs")
  end

  test "a collection merged into one that has records drops the old permissions rather than widen them to those records" do
    create_entry("docs", { "title" => "Merged" })
    create_entry("articles", { "title" => "Already here" })
    delegate("entries.docs.edit")
    drop_schema("collections", "docs")
    migration("2026_10_30_merge_docs", { "rename_collection" => { "from" => "docs", "to" => "articles" } })

    assert_match "dropping docs's permissions from 2 roles and apps", run_migrations.first.counts.first.first
    assert_equal [ false, false ], person_and_app_can?("entries.articles.edit")
    assert_equal %w[apps.connect], Nibble::Role.find_by!(handle: "specific").abilities
  end

  test "a dry run of a rename moves no menu and no permission" do
    menu = save_menu("en", [ { "type" => "url", "title" => "Home", "url" => "/" } ])
    delegate("navigation.docs_menu.edit")
    move_schema("navigation", "docs_menu", "guide_menu")
    migration("2026_10_30_rename_menu", { "rename_navigation" => { "from" => "docs_menu", "to" => "guide_menu" } })

    assert_equal 1, run_migrations(dry_run: true).first.counts.first.last
    assert_equal "docs_menu", menu.reload.handle
    assert_equal %w[navigation.docs_menu.edit apps.connect], Nibble::Role.find_by!(handle: "specific").abilities
  end

  test "nibble:check warns about a stored menu the schema no longer has, until a migration is written for it" do
    save_menu("en", [ { "type" => "url", "title" => "Home", "url" => "/" } ])
    drop_schema("navigation", "docs_menu")

    warning = Nibble::Check.run.warnings.find { |item| item.source == "navigation 'docs_menu'" }
    assert_match "isn't in the schema; add a rename_navigation or delete_navigation migration", warning&.message

    migration("2026_10_30_drop_menu", { "delete_navigation" => { "navigation" => "docs_menu" } })
    assert_nil Nibble::Check.run.warnings.find { |item| item.source == "navigation 'docs_menu'" }
  end

  # The check runs before content migrations on every deploy, so an error here would stop the very deploy that fixes it.
  test "a role naming a handle that a pending migration renames doesn't stop the deploy" do
    save_menu("en", [ { "type" => "url", "title" => "Home", "url" => "/" } ])
    Nibble::Role.create!(handle: "specific", title: "Specific", abilities: %w[navigation.docs_menu.edit])
    move_schema("navigation", "docs_menu", "guide_menu")

    assert(Nibble::Check.run.problems.any? { |problem| problem.message.include?("'navigation.docs_menu.edit' doesn't match") })

    migration("2026_10_30_rename_menu", { "rename_navigation" => { "from" => "docs_menu", "to" => "guide_menu" } })
    assert_not(Nibble::Check.run.problems.any? { |problem| problem.source == "role 'specific'" })
  end

  test "a site's own migrations belong to that site, not to whatever runs these tests" do
    site_layer = Nibble::ContentMigrations.layers.to_h.fetch(:site)

    assert_equal Nibble.config.site_schema_path, site_layer
    assert_not_equal Nibble.site_schema_path, site_layer,
                     "the schema layers are configured, so a real site's migrations cannot reach a fixture"
  end
end
