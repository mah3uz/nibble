module NibbleStarterHelper
  def self.included(base)
    base.setup { use_nibble_starter }
    base.teardown { reset_nibble_starter }
  end

  def use_nibble_starter
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "url" => "https://example.test",
      "locales" => [ { "code" => "en", "default" => true } ], "reserved_paths" => [ "/admin" ],
      "assets" => { "presets" => { "og" => { "w" => 1200, "h" => 630, "fit" => "crop" } } } },
      themes_path: Rails.root.join("test/nibble_themes"),
      site_schema_path: Rails.root.join("test/nibble_themes/no_site_schema"),
      published_path: Pathname(Dir.mktmpdir("nibble-published")))
    Nibble.reset_schema!
    Nibble.boot!
    Nibble::PageCache.store = ActiveSupport::Cache::MemoryStore.new
  end

  def reset_nibble_starter
    Nibble::PageCache.store = nil
    Nibble.config = nil
    Nibble.reset_schema!
    Nibble.boot!
  end

  def seed_starter_site
    @design = term("Design")
    @culture = term("Culture")
    @home = page({ "title" => "Home", "slug" => "home", "template" => "home" })
    @blog = page({ "title" => "Blog", "template" => "posts/index" })
    @about = page({ "title" => "About" })
    @team = page({ "title" => "Team", "parent_id" => @about.id })
    @posts = [
      post({ "title" => "Colour theory", "topics" => [ @design.id.to_s ] }, 5.days.ago),
      post({ "title" => "Grids", "topics" => [ @design.id.to_s ] }, 4.days.ago),
      post({ "title" => "Remote work", "topics" => [ @culture.id.to_s ] }, 3.days.ago),
      post({ "title" => "Type scales", "topics" => [ @design.id.to_s, @culture.id.to_s ] }, 2.days.ago)
    ]
    ok Nibble::Lifecycle.call(Nibble::Records::GlobalSet.new(handle: "site", locale: "en"), :save, { "name" => "Starter" })
    ok Nibble::Lifecycle.call(Nibble::Records::NavigationTree.new(handle: "main", locale: "en"), :save,
      { "tree" => [ { "type" => "entry", "id" => @blog.id }, { "type" => "entry", "id" => @about.id, "children" => [ { "type" => "entry", "id" => @team.id } ] } ] })
    Nibble::Events.dispatch_pending
    Nibble::PageCache.store.clear
  end

  def ok(result)
    assert result.ok?, result.errors.inspect
    result.record
  end

  def term(title) = ok(Nibble::Lifecycle.call(Nibble::Records::Term.new(taxonomy: "topics"), :create, { "title" => title }))

  def page(attrs)
    entry = ok(Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "pages"), :create, attrs))
    ok(Nibble::Lifecycle.call(entry, :publish))
  end

  def post(attrs, published_at)
    entry = ok(Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "posts"), :create, attrs))
    ok(Nibble::Lifecycle.call(entry, :publish, { "published_at" => published_at.utc.iso8601 }))
  end

  def page_props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def query_count = response.headers["X-Nibble-Queries"].to_i
end
