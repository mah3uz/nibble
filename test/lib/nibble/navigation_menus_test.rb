require "test_helper"

class Nibble::NavigationMenusTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

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
      { "type" => "url", "title" => "Top", "url" => "/blog#top" }
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
end
