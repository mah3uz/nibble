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

  # A snippet is read as text beside a title, so the syntax that shapes a page would reach a reader as noise.
  test "a page's Markdown is indexed as the words it renders, not its syntax" do
    with_help_folder("docs/reminders.md" => article("reminders", "Payment reminders",
      "Chase **overdue** invoices from [the list](other.md).\n\n![The overdue list](list.png)")) do
      Nibble::Search.sync_files
      snippet = Nibble::Search.search("site", "overdue", locale: "en").hits.sole.snippet

      assert_includes snippet, "Chase <mark>overdue</mark> invoices from the list."
      assert_no_match(/\*\*|\]\(|!\[/, snippet)
    end
  end

  # Ranking weighs how often a word appears, so a page whose words were stored twice would outrank its equals.
  test "a page's words are indexed once, whether or not its blueprint gives them a field" do
    with_help_folder("docs/reminders.md" => article("reminders", "Payment reminders", "Chase overdue invoices.")) do
      Nibble::Search.sync_files
      body = ActiveRecord::Base.connection.select_value("SELECT body FROM search_index WHERE record_id = 'reminders'")

      assert_equal 1, body.scan("overdue").size
    end
  end

  # An editor hides a page from the site's own search without hiding it from anything else.
  test "a page or entry that says search: false is left out, and one that says nothing is searched" do
    with_help_folder("docs/hidden.md" => "---\nid: hidden\ntitle: Hidden\nsearch: false\n---\n\nOverdue thanks page.\n",
                     "docs/shown.md" => article("shown", "Shown", "Overdue invoices.")) do
      Nibble::Search.sync_files
      assert_equal [ "Shown" ], search("overdue").records.map(&:title)
    end

    post = Nibble::Records::Entry.find_by!(collection: "posts", title: "Colour theory")
    post.update!(data: post.data.merge("search" => false))
    Nibble::Search.index_record(post)
    assert_not_includes search("colour").records, post
  end

  # One index serves a whole site, so a search box scoped to one part of it narrows by collection instead of needing
  # an index of its own.
  test "a search narrows to the collections its where names, and a blank one narrows nothing" do
    with_help_folder("docs/colour.md" => article("colour", "Colour in the docs", "Colour guidance.")) do
      Nibble::Search.sync_files
      Nibble::Search.rebuild

      assert_equal [ "Colour in the docs" ], search("colour", where: { collection: "docs" }).records.map(&:title)
      assert_equal [ "Colour theory" ], search("colour", where: { collection: { in: [ "posts" ] } }).records.map(&:title)
      assert_equal 2, search("colour", where: { collection: "$params.section" }).records.size
      assert_raises(Nibble::Query::Invalid) { search("colour", where: { collection: { ne: "docs" } }) }
    end
  end

  def with_site_schema(files, load_defaults: "0.15.0")
    site = Pathname(Dir.mktmpdir("nibble-site-schema"))
    files.each { |path, data| site.join(path).dirname.mkpath; site.join(path).write(data.to_yaml) }
    Nibble.config = Nibble::Config.new(Nibble.config_values.merge("theme" => "starter", "load_defaults" => load_defaults),
      themes_path: Rails.root.join("test/nibble_themes"), site_schema_path: site, content_path: Rails.root.join("test/nibble_content"))
    Nibble.reset_schema!
    Nibble::Search.rebuild
    yield
  end

  # The key read one way and behaved another, which is how a collection said `search: site` and was never searched.
  test "a collection that names an index is searched in it, even when search.yml leaves it out" do
    posts = YAML.load_file(Rails.root.join("vendor/nibble/core_schema/collections/posts.yml"))
    assert_equal "site", posts["search"]
    with_site_schema({ "collections/posts.yml" => posts,
                       "search.yml" => { "schema" => 1, "indexes" => { "site" => { "collections" => [ "pages" ] } } } }) do
      assert_includes Nibble::Search.indexes["site"]["collections"], "posts"
      assert_equal [ "Grids" ], search("grids").records.map(&:title)
    end
  end

  test "a collection with search: false leaves every index, even one search.yml puts it in" do
    posts = YAML.load_file(Rails.root.join("vendor/nibble/core_schema/collections/posts.yml")).merge("search" => false)
    with_site_schema({ "collections/posts.yml" => posts,
                       "search.yml" => { "schema" => 1, "indexes" => { "site" => { "collections" => %w[pages posts] } } } }) do
      assert_not_includes Nibble::Search.indexes["site"]["collections"], "posts"
      assert_empty search("grids").records
    end
  end

  # Search membership changing under a site is something it would notice, so it waits for load_defaults.
  test "a site that has not raised load_defaults keeps search.yml in charge" do
    posts = YAML.load_file(Rails.root.join("vendor/nibble/core_schema/collections/posts.yml"))
    with_site_schema({ "collections/posts.yml" => posts,
                       "search.yml" => { "schema" => 1, "indexes" => { "site" => { "collections" => [ "pages" ] } } } }, load_defaults: "0.14.7") do
      assert_equal [ "pages" ], Nibble::Search.indexes["site"]["collections"]
    end
  end

  # Two places to say the same thing is how a collection came to look searched and not be, so from 0.17.0 there is one.
  test "from 0.17.0 an index is made of what names it, and search.yml keeps only its settings" do
    topics = YAML.load_file(Rails.root.join("test/nibble_themes/starter/schema/taxonomies/topics.yml")).merge("search" => "site")
    with_site_schema({ "taxonomies/topics.yml" => topics,
                       "search.yml" => { "schema" => 1, "indexes" => { "site" => { "collections" => [ "docs" ], "fields" => [ "title" ] } } } },
                     load_defaults: "0.17.0") do
      site = Nibble::Search.indexes["site"]

      assert_includes site["collections"], "pages"
      assert_not_includes site["collections"], "docs", "listed only in search.yml, so it isn't searched"
      assert_equal [ "topics" ], site["taxonomies"]
      assert_equal [ "title" ], site["fields"]
    end
  end

  # A result is read in a list of many, so it says which section it sits in; a query asks for that only when it shows it.
  test "a result asked for its parent names the section it sits in, and a top-level one has none" do
    with_help_folder("docs/index.md" => article("docs-home", "Docs", "Start here."),
                     "docs/overview.md" => article("overview", "Overview", "Invoices at a glance."),
                     "docs/billing/index.md" => article("billing", "Billing", "Getting paid."),
                     "docs/billing/reminders.md" => article("reminders", "Payment reminders", "Chase overdue invoices.")) do
      Nibble::Search.sync_files
      presented = ->(query) { Nibble::Presenter.present(search(query).records, fields: %w[title parent]).sole }

      assert_equal({ "title" => "Billing", "uri" => "/docs/billing" }, presented.("overdue")["parent"])
      assert_nil presented.("glance")["parent"]
      assert_not Nibble::Presenter.present(search("overdue").records).sole.key?("parent"), "nobody asked, so nothing is looked up"
    end
  end
end
