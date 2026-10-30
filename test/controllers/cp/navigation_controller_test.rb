require "test_helper"

class Nibble::Cp::NavigationControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup do
    use_site_addresses(apply_url: "https://apply.example.test")
    @nibble_themes.join("records", "schema", "navigation", "rich.yml").write({
      "title" => "Rich", "collections" => [ "articles" ], "headings" => true, "globals" => true, "assets" => true,
      "item_fields" => [ { "handle" => "badge", "field" => { "type" => "text" } }, { "handle" => "featured", "field" => { "type" => "toggle" } } ]
    }.to_yaml)
    Nibble.reset_schema!
    sign_in_as users(:editor)
  end

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]

  test "the editor's tree carries every stored key, so saving it back changes nothing" do
    asset = create_asset
    post = publish_entry(create_entry("articles", { "title" => "Post" }))
    stored = [
      { "kind" => "heading", "title" => "Company", "hidden" => true, "children" => [
        { "type" => "global", "ref" => "global:site.apply_url", "title" => "Apply", "new_tab" => true, "children" => [] },
        { "type" => "asset", "id" => asset.id, "title" => "Prices", "fields" => { "badge" => "PDF", "featured" => true }, "children" => [] }
      ] },
      { "type" => "entry", "id" => post.id, "title" => "Post", "children" => [] },
      { "type" => "url", "url" => "/a", "title" => "A", "children" => [] }
    ]
    assert lifecycle(Nibble::Records::NavigationTree.new(handle: "rich", locale: "en"), :save, "tree" => stored).ok?

    get "/cp/navigation/rich/edit"
    assert_equal [ "heading", nil ], props["tree"].first.values_at("kind", "link")
    patch "/cp/navigation/rich", params: { tree: props["tree"] }, as: :json

    off = ->(nodes) { nodes.map { |node| { "fields" => { "featured" => false } }.merge(node).merge("children" => off.(node["children"])) } }
    assert_equal off.(stored), Nibble::Records::NavigationTree.find_by!(handle: "rich").tree,
      "nothing stored is lost; an item without fields gains its toggle switched off, as an entry does"
  end

  test "a refused save says which item each problem is on, so the editor can show it there" do
    tree = [
      { kind: "link", title: "Fine", link: { type: "url", url: "/fine" }, children: [] },
      { kind: "heading", title: "Company", children: [
        { kind: "link", title: "Sneaky", link: { type: "url", url: "javascript:alert(1)" }, children: [] }
      ] }
    ]
    patch "/cp/navigation/rich", params: { tree: }, as: :json
    follow_redirect!

    errors = props["errors"]
    assert_equal [ "tree.1.children.0" ], errors.keys - [ "tree" ]
    assert_match "“Sneaky” must link to", errors["tree.1.children.0"]
    assert_match "Sneaky", errors["tree"], "the first problem is still given for the whole menu"
  end

  test "custom kinds, query items and show dates round-trip through the editor, which is told the kinds and what a query may list" do
    @nibble_themes.join("records", "schema", "navigation", "mega.yml").write({
      "title" => "Mega", "collections" => [ "articles" ], "queries" => [ "docs" ],
      "kinds" => { "featured" => { "display" => "Featured card", "link" => "required", "children" => false,
                                   "fields" => [ { "handle" => "blurb", "field" => { "type" => "text" } } ] } }
    }.to_yaml)
    Nibble.reset_schema!
    post = publish_entry(create_entry("articles", { "title" => "Post" }))
    guides = create_entry("docs", { "title" => "Guides" })
    tag = create_term("News")
    stored = [
      { "kind" => "featured", "type" => "entry", "id" => post.id, "title" => "Post", "fields" => { "blurb" => "New" }, "children" => [] },
      { "kind" => "query", "title" => "Guides", "query" => { "collection" => "docs", "parent" => guides.id, "sort" => "title", "limit" => 5 },
        "show_from" => "2026-11-01T09:00:00Z", "show_until" => "2026-11-08T09:00:00Z", "children" => [] }
    ]
    assert lifecycle(Nibble::Records::NavigationTree.new(handle: "mega", locale: "en"), :save, "tree" => stored).ok?

    get "/cp/navigation/mega/edit"
    assert_equal [ [ "featured", "Featured card", "required", false, [ "blurb" ] ] ],
      props["menu"]["kinds"].map { |kind| [ *kind.values_at("handle", "display", "link", "children"), kind["fields"].map { |field| field["handle"] } ] }
    assert_equal [ [ "docs", true, [ "tags" ] ] ], props["menu"]["queries"].map { |query| [ query["handle"], query["structured"], query["taxonomies"].map { |one| one["handle"] } ] }
    assert_equal [ [ "entry", guides.id ], [ "term", tag.id ] ], props["query_records"].map { |record| record.values_at("type", "id") }
    patch "/cp/navigation/mega", params: { tree: props["tree"] }, as: :json

    assert_equal "Navigation saved.", flash[:notice]
    assert_equal stored, Nibble::Records::NavigationTree.find_by!(handle: "mega").tree, "an editor save keeps a kind's link, the query and the dates"
  end

  test "the editor is told what the menu may hold" do
    get "/cp/navigation/rich/edit"
    menu = props["menu"]

    assert_nil menu["max_depth"], "a menu without max_depth nests without limit, in the editor too"
    assert_equal [ true, true ], menu.values_at("headings", "assets")
    assert_equal [ "site" ], menu["globals"].map { |global| global["handle"] }
    assert_equal %w[badge featured], menu["item_fields"].map { |field| field["handle"] }

    get "/cp/navigation/docs_menu/edit"
    assert_equal [ 2, false, false, [], [] ], props["menu"].values_at("max_depth", "headings", "assets", "globals", "item_fields")
  end
end
