require "test_helper"

class Nibble::SearchTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  setup do
    seed_starter_site
    Nibble::Search.rebuild
  end

  def search(query, **options) = Nibble::Query.build({ from: "search:site", q: query, **options }, Nibble::Query::Context.public).result

  test "live pages and posts are found by stemmed words, best match first, with an escaped highlighted snippet" do
    ok Nibble::Lifecycle.call(@posts[1], :save, { "excerpt" => "Designers <b>love</b> aligning columns" })
    ok Nibble::Lifecycle.call(@posts[1].reload, :publish)
    Nibble::Events.dispatch_pending

    result = search("column")
    assert_equal [ "Grids" ], result.records.map(&:title)
    assert_equal "Designers &lt;b&gt;love&lt;/b&gt; aligning <mark>columns</mark>", result.snippets["entry:#{@posts[1].id}"]
  end

  test "drafts aren't indexed and unpublishing removes a record from results" do
    ok Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts"), :create, { "title" => "Secret grids" })
    Nibble::Events.dispatch_pending
    assert_equal [ "Grids" ], search("grids").records.map(&:title)

    ok Nibble::Lifecycle.call(@posts[1], :unpublish)
    Nibble::Events.dispatch_pending
    assert_empty search("grids").records
  end

  test "user input can't inject search syntax" do
    assert_empty search("\" OR title:* NEAR(").records
    assert_empty Nibble::Search.search("site", "   ", locale: "en").hits
  end

  test "search results paginate with totals" do
    result = search("a", paginate: { per_page: 2 })
    assert_operator result.pagination["total"], :>=, result.records.size
  end

  test "trigram locales match substrings, for languages written without spaces" do
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "url" => "https://example.test", "locales" => [
      { "code" => "en", "default" => true }, { "code" => "ja", "url_prefix" => "/ja", "search_tokenizer" => "trigram" }
    ] }, themes_path: Rails.root.join("test/nibble_themes"))
    post = ok(Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts", locale: "ja"), :create, { "title" => "喫茶店のデザイン" }))
    ok Nibble::Lifecycle.call(post, :publish, { "published_at" => 1.day.ago.utc.iso8601 })
    Nibble::Events.dispatch_pending

    hits = Nibble::Search.search("site", "茶店の", locale: "ja").hits
    assert_equal [ post.id ], hits.map(&:record_id)
    assert_empty Nibble::Search.search("site", "茶店", locale: "ja").hits, "trigram queries need three characters"
  end

  def with_help_folder(files)
    dir = Pathname(Dir.mktmpdir("nibble-content"))
    site = Pathname(Dir.mktmpdir("nibble-site-schema"))
    site.join("search.yml").write({ "schema" => 1, "indexes" => { "site" => { "collections" => %w[pages posts docs] } } }.to_yaml)
    files.each { |path, text| dir.join(path).dirname.mkpath; dir.join(path).write(text) }
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "url" => "https://example.test",
      "locales" => [ { "code" => "en", "default" => true } ] },
      themes_path: Rails.root.join("test/nibble_themes"), site_schema_path: site, content_path: dir,
      published_path: Pathname(Dir.mktmpdir("nibble-published")))
    Nibble.reset_schema!
    Nibble::Files.reload!
    yield dir
  end

  def article(id, title, body) = "---\nid: #{id}\ntitle: #{title}\n---\n\n#{body}\n"

  # A page written as a file publishes no events, so without this nothing would ever put it in the index.
  test "pages written as files are searchable once synced, and a deleted file's page stops being found" do
    with_help_folder("docs/index.md" => article("docs-home", "Docs", "Start here."),
                     "docs/reminders.md" => article("reminders", "Payment reminders", "Chase overdue invoices.")) do |dir|
      Nibble::Search.sync_files
      assert_equal [ "Payment reminders" ], search("overdue").records.map(&:title)

      dir.join("docs/reminders.md").delete
      Nibble::Files.reload!
      Nibble::Search.sync_files
      assert_empty search("overdue").records, "a result pointing at a page that 404s is worse than none"
    end
  end
end
