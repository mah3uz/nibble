require "test_helper"

class Nibble::DriftTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def issues = Nibble::Drift.issues.map { |issue| "#{issue.source}: #{issue.message}" }

  def migration(name, *operations)
    path = @nibble_themes.join("records/schema/migrations/#{name}.yml")
    path.dirname.mkpath
    path.write({ "operations" => operations }.to_yaml)
  end

  def strand(entry, values) = entry.tap { entry.update_columns(data: entry.data.merge(values)) }

  test "a field the schema no longer has, with data still in it, is reported with how much" do
    2.times { |index| strand(create_entry("articles", { "title" => "A#{index}" }), "intro" => "Old") }

    assert_equal [ "collections/articles: intro was removed and 2 records still hold it; #{Nibble::Drift::HINT}" ], issues
  end

  test "a removed field nobody filled in is no loss, so it isn't reported" do
    strand(create_entry("articles", { "title" => "A" }), "intro" => nil)

    assert_empty issues
  end

  test "a pending migration that moves the data covers it" do
    strand(create_entry("articles", { "title" => "A" }), "intro" => "Old")
    migration("2026_10_01_rename", { "rename_field" => { "collection" => "articles", "from" => "intro", "to" => "summary" } })

    assert_empty issues
  end

  test "a draft holding a removed field counts as stranded too" do
    article = publish_entry(create_entry("articles", { "title" => "Live" }))
    lifecycle(article.reload, :save, { "title" => "Edited" })
    article.draft.update_columns(data: article.draft.data.merge("intro" => "In a draft"))

    assert_equal [ "collections/articles: intro was removed and 1 record still hold it; #{Nibble::Drift::HINT}" ], issues
  end

  test "entries on a blueprint that was removed are reported, unless a migration moves them" do
    create_entry("articles", { "title" => "A" }).update_columns(blueprint: "landing")

    assert_match "blueprint 'landing' was removed and 1 record still use it", issues.sole

    migration("2026_10_01_move", { "change_blueprint" => { "collection" => "articles", "from" => "landing", "to" => "article" } })
    assert_empty issues
  end

  test "records in a collection the schema dropped are reported" do
    create_entry("articles", { "title" => "A" }).update_columns(collection: "news")

    assert_equal [ "collections/news: collection 'news' was removed and 1 record still belong to it" ], issues
  end

  test "a field whose type changed while holding data is caught against the last snapshot" do
    create_entry("articles", { "title" => "A", "summary" => "Some text" })
    assert_empty issues, "no snapshot yet, so nothing to compare types with"

    Nibble::Drift.record_snapshot!
    snapshot = Nibble::Records::SchemaSnapshot.latest
    snapshot.update_columns(types: snapshot.types.deep_merge("collections/articles" => { "summary" => "toggle" }))

    assert_equal [ "collections/articles: summary changed from toggle to textarea and 1 record hold a value; #{Nibble::Drift::HINT}" ], issues
  end

  test "a snapshot is only written when the types actually changed" do
    assert Nibble::Drift.record_snapshot!
    assert_not Nibble::Drift.record_snapshot!
    assert_equal 1, Nibble::Records::SchemaSnapshot.count
  end

  test "nibble:check fails on stranded data, and --allow-data-loss turns it into a warning" do
    strand(create_entry("articles", { "title" => "A" }), "intro" => "Old")

    blocked = Nibble::Check.run
    assert_not blocked.ok?
    assert(blocked.problems.any? { |problem| problem.message.include?("intro was removed") })

    allowed = Nibble::Check.run(allow_data_loss: true)
    assert(allowed.warnings.any? { |warning| warning.message.include?("intro was removed") })
    assert(allowed.problems.none? { |problem| problem.message.include?("intro was removed") })
  end
end
