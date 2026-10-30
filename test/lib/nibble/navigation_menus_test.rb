require "test_helper"

class Nibble::NavigationMenusTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  Tree = Nibble::Records::NavigationTree

  setup do
    use_site_addresses(apply_url: "https://apply.example.test/one")
    menus = @nibble_themes.join("records", "schema", "navigation")
    menus.join("plain.yml").write({ "title" => "Plain", "collections" => [ "articles" ] }.to_yaml)
    menus.join("rich.yml").write({
      "title" => "Rich", "collections" => [ "articles" ], "headings" => true, "globals" => [ "site" ], "assets" => true,
      "entry_fields" => [ "summary" ],
      "item_fields" => [ { "handle" => "badge", "field" => { "type" => "text", "validate" => [ "max:5" ] } },
                         { "handle" => "featured", "field" => { "type" => "toggle" } },
                         { "handle" => "related", "field" => { "type" => "entries", "collections" => [ "articles" ] } } ]
    }.to_yaml)
    Nibble.reset_schema!
  end

  def save(handle, tree) = lifecycle(Tree.find_or_initialize_by(handle:, locale: "en"), :save, "tree" => tree)
  def saved!(handle, tree) = save(handle, tree).tap { |result| assert result.ok?, result.errors.inspect }.record
  def present(tree) = Nibble::Presenter.new(context: Nibble::Query::Context.public).present_navigation(tree.reload)
  def article(attrs = {}) = publish_entry(create_entry("articles", attrs)).reload
  def refused(handle, tree) = save(handle, tree).errors.values.flatten.join(" ")

  test "a menu that declares nothing new presents its links as before, with the new keys added" do
    post = article("title" => "Post")
    tree = saved!("plain", [ { "type" => "entry", "id" => post.id, "children" => [ { "type" => "url", "title" => "Home", "url" => "/" } ] } ])

    assert_equal [ { "type" => "entry", "id" => post.id, "title" => "Post", "url" => post.uri,
                     "kind" => "link", "new_tab" => false, "fields" => {}, "entry" => nil,
                     "children" => [ { "type" => "url", "title" => "Home", "url" => "/",
                                       "kind" => "link", "new_tab" => false, "fields" => {}, "entry" => nil, "children" => [] } ] } ],
      present(tree)
    assert_equal [ { "type" => "entry", "id" => post.id, "children" => [ { "type" => "url", "title" => "Home", "url" => "/" } ] } ], tree.tree,
      "a stored node without a kind is a link, and nothing is added to it"
  end

  test "a heading has a title and no address, and only a menu that allows headings has one" do
    tree = saved!("rich", [ { "kind" => "heading", "title" => "Company", "children" => [ { "type" => "url", "title" => "Jobs", "url" => "/jobs" } ] } ])

    heading = present(tree).first
    assert_equal [ "heading", nil, nil, "Company" ], heading.values_at("kind", "type", "url", "title")
    assert_equal [ "/jobs" ], heading["children"].map { |link| link["url"] }

    assert_match "doesn't allow", refused("plain", [ { "kind" => "heading", "title" => "Company" } ]),
      "a theme written for a menu without headings expects every url to be a string"
    assert_match "can't link anywhere", refused("rich", [ { "kind" => "heading", "title" => "Company", "type" => "url", "url" => "/x" } ])
    assert_match "doesn't support", refused("rich", [ { "kind" => "banner", "title" => "Sale" } ])
  end

  test "a heading left behind when a menu stops allowing them never reaches a theme" do
    tree = saved!("rich", [ { "kind" => "heading", "title" => "Company" }, { "type" => "url", "title" => "Jobs", "url" => "/jobs" } ])
    tree.update_columns(handle: "plain")

    assert_equal [ "/jobs" ], present(tree).map { |link| link["url"] }
  end

  test "a global link shows the global's current address and purges with it" do
    tree = saved!("rich", [ { "type" => "global", "ref" => "global:site.apply_url", "title" => "Apply" } ])

    links, tags = Nibble::Dependencies.track { present(tree) }
    assert_equal [ "global", "Apply", "https://apply.example.test/one" ], links.first.values_at("type", "title", "url")
    assert_includes tags, "global:site", "saving the global purges this tag, so every page with the menu shows the new address"

    site = Nibble::Records::GlobalSet.find_by!(handle: "site")
    assert lifecycle(site, :save, "apply_url" => "https://apply.example.test/two").ok?
    assert_equal "https://apply.example.test/two", present(tree).first["url"], "the menu wasn't saved again, yet follows the global"

    site.update_columns(data: site.data.merge("apply_url" => "javascript:alert(1)"))
    assert_empty present(tree), "a global holding an unsafe address gives no link at all"
  end

  test "a global link must name an address field of a global the menu allows" do
    assert_match "can't link to", refused("plain", [ { "type" => "global", "ref" => "global:site.apply_url", "title" => "Apply" } ])
    assert_match "doesn't hold an address", refused("rich", [ { "type" => "global", "ref" => "global:site.name", "title" => "Name" } ])
    assert_match "needs a title", refused("rich", [ { "type" => "global", "ref" => "global:site.apply_url" } ])
  end

  test "an asset link points at the file's public address and is tagged with it" do
    asset = create_asset({ "title" => "Price list" })
    tree = saved!("rich", [ { "type" => "asset", "id" => asset.id } ])

    links, tags = Nibble::Dependencies.track { present(tree) }
    assert_equal [ "asset", asset.id, "Price list", asset.url ], links.first.values_at("type", "id", "title", "url")
    assert_includes tags, "asset:#{asset.id}"
    assert_match "can't link to", refused("plain", [ { "type" => "asset", "id" => asset.id } ])
  end

  test "an unsafe address is refused" do
    [ "javascript:alert(1)", "data:text/html,<script>alert(1)</script>", " vbscript:x" ].each do |url|
      assert_match "must link to a web page", refused("rich", [ { "type" => "url", "title" => "Bad", "url" => url } ])
    end
  end

  test "item fields are validated, stored as their fieldtypes store them, and augmented for the theme" do
    linked = article("title" => "Linked")
    assert_match "Badge", refused("rich", [ { "type" => "url", "title" => "A", "url" => "/a", "fields" => { "badge" => "far too long" } } ])
    assert_match "aren't a set of values", refused("rich", [ { "type" => "url", "title" => "A", "url" => "/a", "fields" => "new" } ])

    tree = saved!("rich", [ { "type" => "url", "title" => "A", "url" => "/a",
                              "fields" => { "badge" => "New", "featured" => "1", "related" => [ linked.id.to_s ] } } ])
    assert_equal true, tree.tree.first["fields"]["featured"]

    fields, tags = Nibble::Dependencies.track { present(tree).first["fields"] }
    assert_equal [ "New", true ], fields.values_at("badge", "featured")
    assert_equal [ "Linked" ], fields["related"].map { |summary| summary["title"] }, "a relationship arrives as the records it names"
    assert_includes tags, "entry:#{linked.id}"
  end

  test "entry_fields exposes only the listed fields of a linked entry" do
    post = article("title" => "Post", "summary" => "Short", "seats" => 20)
    tree = saved!("rich", [ { "type" => "entry", "id" => post.id }, { "type" => "url", "title" => "Out", "url" => "/out" } ])

    links, tags = Nibble::Dependencies.track { present(tree) }
    assert_equal({ "summary" => "Short" }, links.first["entry"])
    assert_nil links.last["entry"], "a typed address has no entry"
    assert_includes tags, "entry:#{post.id}"
  end

  test "hidden items and everything under them never reach a theme" do
    tree = saved!("rich", [ { "type" => "url", "title" => "Parked", "url" => "/parked", "hidden" => true,
                              "children" => [ { "type" => "url", "title" => "Under", "url" => "/under" } ] },
                            { "type" => "url", "title" => "Shown", "url" => "/shown", "new_tab" => true } ])

    assert_equal [ [ "Shown", true ] ], present(tree).map { |link| link.values_at("title", "new_tab") }
    assert_match "true or false", refused("rich", [ { "type" => "url", "title" => "A", "url" => "/a", "hidden" => "yes" } ])
  end

  test "an asset and an item field's records are recorded as relations, so the menu is preloaded in one pass" do
    asset = create_asset
    linked = article
    saved!("rich", [ { "type" => "asset", "id" => asset.id, "fields" => { "related" => [ linked.id.to_s ] } } ])

    assert_equal [ [ "asset", asset.id ], [ "entry", linked.id ] ],
      Nibble::Records::Relation.where(source_type: "navigation").order(:position).pluck(:target_type, :target_id)
  end

  test "current and in_trail follow the page's path" do
    saved!("plain", [
      { "type" => "url", "title" => "Home", "url" => "/" },
      { "type" => "url", "title" => "Blog", "url" => "/blog/" },
      { "type" => "url", "title" => "About", "url" => "https://example.com/about" },
      { "type" => "url", "title" => "Elsewhere", "url" => "https://elsewhere.test/blog" },
      { "type" => "url", "title" => "Top", "url" => "https://example.com/blog#top" }
    ])
    match = Nibble::Routing.resolve(article.uri)
    flags = lambda do |path|
      Nibble::PageProps.new(match, request_path: path).build.props["site"]["navigation"]["plain"]
        .to_h { |link| [ link["title"], [ link["current"], link["in_trail"] ] ] }
    end

    assert_equal [ true, true ], flags.("/blog")["Blog"], "a trailing slash doesn't make it another page"
    assert_equal [ false, true ], flags.("/blog/a-post")["Blog"], "a page under the item's path is in its trail"
    assert_equal [ false, false ], flags.("/blog/a-post")["Home"], "the home page is only ever current on itself"
    assert_equal [ true, true ], flags.("/")["Home"]
    assert_equal [ true, true ], flags.("/about")["About"], "a full address on this site is a path here"
    assert_equal [ false, false ], flags.("/blog")["Elsewhere"], "another site's /blog isn't this page"
    assert_equal [ false, false ], flags.("/blog")["Top"], "a link into part of a page isn't the page"
    assert_equal [ false, false ], flags.("/blogging")["Blog"], "a path that merely starts the same isn't under it"
  end

  test "a heading is in the trail when one of its children is" do
    saved!("rich", [ { "kind" => "heading", "title" => "Writing", "children" => [ { "type" => "url", "title" => "Blog", "url" => "/blog" } ] } ])
    menu = Nibble::PageProps.new(Nibble::Routing.resolve(article.uri), request_path: "/blog/a-post").build.props["site"]["navigation"]["rich"]

    assert_equal [ false, true ], menu.first.values_at("current", "in_trail")
  end

  def use_mega_menu
    menus = @nibble_themes.join("records", "schema", "navigation")
    menus.join("mega.yml").write({
      "title" => "Mega", "collections" => [ "articles", "docs" ], "queries" => [ "docs", "articles" ],
      "item_fields" => [ { "handle" => "badge", "field" => { "type" => "text" } } ],
      "kinds" => {
        "featured" => { "display" => "Featured card", "link" => "required", "children" => false,
                        "fields" => [ { "handle" => "blurb", "field" => { "type" => "text", "required" => true, "validate" => [ "max:20" ] } },
                                      { "handle" => "image", "field" => { "type" => "assets", "max_files" => 1 } } ] },
        "column" => { "link" => "none" }
      }
    }.to_yaml)
    Nibble.reset_schema!
  end

  def doc(title, parent: nil, publish: true)
    entry = create_entry("docs", { "title" => title, "parent_id" => parent&.id }.compact)
    return entry unless publish

    lifecycle(entry, :submit)
    lifecycle(entry.reload, :approve)
    publish_entry(entry.reload).reload
  end

  test "a custom kind follows its link and children rules, and its fields are validated and augmented with the item fields" do
    use_mega_menu
    post = article("title" => "Launch")
    asset = create_asset({ "title" => "Banner" })

    assert_match "Featured card, which needs a link", refused("mega", [ { "kind" => "featured", "title" => "Sale", "fields" => { "blurb" => "Half off" } } ]),
      "a theme renders a featured card as a link, so one without a link must not be saved"
    assert_match "Blurb", refused("mega", [ { "kind" => "featured", "type" => "entry", "id" => post.id } ])
    assert_match "Blurb", refused("mega", [ { "kind" => "featured", "type" => "entry", "id" => post.id, "fields" => { "blurb" => "far more than twenty letters" } } ])
    assert_match "can't have items under it", refused("mega", [ { "kind" => "featured", "type" => "entry", "id" => post.id, "fields" => { "blurb" => "New" },
                                                                   "children" => [ { "type" => "url", "title" => "A", "url" => "/a" } ] } ])
    assert_match "Column, so it can't link anywhere", refused("mega", [ { "kind" => "column", "title" => "Shop", "type" => "url", "url" => "/shop" } ])

    tree = saved!("mega", [
      { "kind" => "featured", "type" => "entry", "id" => post.id, "fields" => { "blurb" => "New", "badge" => "Hot", "image" => [ asset.id.to_s ] } },
      { "kind" => "column", "title" => "Shop", "children" => [ { "type" => "url", "title" => "Shoes", "url" => "/shoes" } ] }
    ])
    featured, column = present(tree)
    assert_equal [ "featured", "entry", post.uri, "Launch" ], featured.values_at("kind", "type", "url", "title")
    assert_equal [ "New", "Hot" ], featured["fields"].values_at("blurb", "badge"), "a custom kind carries the menu's item fields as well as its own"
    assert_equal "Banner", featured["fields"]["image"]["title"], "a kind's asset field arrives as the file, as an item field's would"
    assert_equal [ "column", nil, nil, [ "/shoes" ] ], [ *column.values_at("kind", "type", "url"), column["children"].map { |link| link["url"] } ]
    assert_includes Nibble::Records::Relation.where(source_type: "navigation").pluck(:target_type, :target_id), [ "asset", asset.id ],
      "a kind's fields are relations too, so the file is preloaded and its deletion is known"
  end

  test "a query item lists the parent's published child pages, with no menu edit when one is added, and never a draft" do
    use_mega_menu
    guides = doc("Guides")
    doc("Install", parent: guides)
    doc("Elsewhere")
    tree = saved!("mega", [ { "kind" => "query", "title" => "Guides", "query" => { "collection" => "docs", "parent" => guides.id, "sort" => "title" } } ])

    item, tags = Nibble::Dependencies.track { present(tree).first }
    assert_equal [ "query", nil, nil, "Guides" ], item.values_at("kind", "type", "url", "title")
    assert_equal [ "Install" ], item["children"].map { |link| link["title"] }
    assert_includes tags, "collection:docs", "any change to the collection purges every page with the menu, so a new page shows up"

    doc("Configure", parent: guides)
    doc("Unfinished", parent: guides, publish: false)
    children = present(tree).first["children"]
    assert_equal [ "Configure", "Install" ], children.map { |link| link["title"] }, "the menu wasn't saved again, and a draft isn't listed"
    assert_equal({ "kind" => "link", "type" => "entry", "new_tab" => false, "fields" => { "badge" => nil }, "entry" => nil, "children" => [] },
      children.first.slice("kind", "type", "new_tab", "fields", "entry", "children"), "a listed page is shaped like any other entry link")
  end

  test "a query item can list a collection's entries tagged with a term, and is in the trail of the page it lists" do
    use_mega_menu
    news = create_term("News")
    tagged = article("title" => "Tagged", "tags" => [ news.id.to_s ])
    mentions = article("title" => "Mentions")
    Nibble::Records::Relation.create!(source_type: "entry", source_id: mentions.id, field: "blocks", locale: "en", target_type: "term", target_id: news.id, position: 0)
    saved!("mega", [ { "kind" => "query", "title" => "News", "query" => { "collection" => "articles", "term" => { "taxonomy" => "tags", "id" => news.id } } } ])

    menu = Nibble::PageProps.new(Nibble::Routing.resolve(tagged.uri), request_path: tagged.uri).build.props["site"]["navigation"]["mega"]
    assert_equal [ "Tagged" ], menu.first["children"].map { |link| link["title"] }, "a page that only links to the term in its text isn't tagged with it"
    assert_equal [ true, true ], menu.first["children"].first.values_at("current", "in_trail")
    assert_equal [ false, true ], menu.first.values_at("current", "in_trail")
  end

  test "a query item may only list a collection the menu names in queries, and only within its bounds" do
    use_mega_menu
    guides = doc("Guides")
    post = article

    assert_match "lists pages, which this menu doesn't allow", refused("rich", [ { "kind" => "query", "title" => "All", "query" => { "collection" => "articles" } } ])
    assert_match "lists Pages, which this menu can't list", refused("mega", [ { "kind" => "query", "title" => "All", "query" => { "collection" => "pages" } } ]),
      "a menu lists only the collections its schema allows, so its cost is the developer's choice"
    assert_match "isn't in Docs", refused("mega", [ { "kind" => "query", "title" => "All", "query" => { "collection" => "docs", "parent" => post.id } } ])
    assert_match "from 1 to 50", refused("mega", [ { "kind" => "query", "title" => "All", "query" => { "collection" => "docs", "limit" => 500 } } ])
    assert_match "sorted", refused("mega", [ { "kind" => "query", "title" => "All", "query" => { "collection" => "docs", "sort" => "nope" } } ])
    assert_match "needs a title", refused("mega", [ { "kind" => "query", "query" => { "collection" => "docs" } } ])
    assert_match "rather than being added", refused("mega", [ { "kind" => "query", "title" => "All", "query" => { "collection" => "docs", "parent" => guides.id },
                                                                "children" => [ { "type" => "url", "title" => "A", "url" => "/a" } ] } ])
  end

  test "an item shows only between its dates, and everything under it with it" do
    tree = saved!("plain", [ { "type" => "url", "title" => "Sale", "url" => "/sale", "show_from" => "2026-11-01T09:00:00Z", "show_until" => "2026-11-08T09:00:00Z",
                               "children" => [ { "type" => "url", "title" => "Shoes", "url" => "/sale/shoes" } ] },
                             { "type" => "url", "title" => "Home", "url" => "/" } ])
    at = ->(time) { Nibble::Presenter.new(context: Nibble::Query::Context.public(now: Time.iso8601(time))).present_navigation(tree.reload).map { |link| link["title"] } }

    assert_equal [ "Home" ], at.("2026-11-01T08:59:59Z")
    assert_equal [ "Sale", "Home" ], at.("2026-11-01T09:00:00Z")
    assert_equal [ "Sale", "Home" ], at.("2026-11-08T08:59:59Z")
    assert_equal [ "Home" ], at.("2026-11-08T09:00:00Z")

    assert_match "isn't a date and time", refused("plain", [ { "type" => "url", "title" => "A", "url" => "/a", "show_from" => "next week" } ])
    assert_match "stops showing before it starts", refused("plain", [ { "type" => "url", "title" => "A", "url" => "/a",
                                                                       "show_from" => "2026-11-08T09:00:00Z", "show_until" => "2026-11-01T09:00:00Z" } ])
  end

  test "saving a menu with a future date enqueues a purge of the menu at that date, so cached pages change on time" do
    from = 2.days.from_now.change(usec: 0)
    tree = saved!("plain", [ { "type" => "url", "title" => "Sale", "url" => "/sale", "show_from" => from.iso8601 },
                             { "type" => "url", "title" => "Old", "url" => "/old", "show_until" => "2020-01-01T00:00:00Z" } ])
    purges = enqueued_jobs.select { |job| job["job_class"] == "Nibble::Jobs::PurgeNavigation" }
    assert_equal [ [ [ tree.id ], (from + Nibble::Jobs::PurgeNavigation::GRACE).to_f ] ], purges.map { |job| [ job["arguments"], Time.iso8601(job["scheduled_at"]).to_f ] },
      "only a date still to come needs a purge"

    Nibble::PageCache.store = ActiveSupport::Cache::MemoryStore.new
    Nibble::PageCache.write("with-menu", [ "navigation:plain" ], body: "old", content_type: "text/html")
    Nibble::PageCache.write("without", [ "navigation:rich" ], body: "kept", content_type: "text/html")
    Nibble::Jobs::PurgeNavigation.perform_now(0)
    assert Nibble::PageCache.read("with-menu"), "a job for a menu that's gone does nothing"

    2.times { Nibble::Jobs::PurgeNavigation.perform_now(tree.id) }
    assert_nil Nibble::PageCache.read("with-menu"), "a page showing the menu renders again, so the item appears"
    assert Nibble::PageCache.read("without"), "a repeated purge clears only the menu's pages"
  ensure
    Nibble::PageCache.store = nil
  end
end
