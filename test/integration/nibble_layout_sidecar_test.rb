require "test_helper"

# A layout's sidecar feeds the header and footer every page shares, so what it asks for must reach every page that
# uses the layout, keep the page cache honest, and let the page's own record bring its related records along.
class NibbleLayoutSidecarTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  setup do
    @themes = Pathname(Dir.mktmpdir("nibble-layouts"))
    FileUtils.cp_r(Rails.root.join("test/nibble_themes/starter"), @themes.join("starter"))
    use_nibble_starter(themes_path: @themes)
    seed_starter_site
  end

  teardown { FileUtils.rm_rf(@themes) }

  def write(relative, content) = @themes.join("starter", relative).tap { |path| path.dirname.mkpath }.write(content.to_yaml)

  def layout(content) = write("layouts/default.yml", content)

  test "a layout's queries reach an entry, a listing and the 404 page" do
    layout("footer_topics" => { "from" => "terms:topics", "fields" => %w[title uri] })

    [ @posts.first.uri, "/journal", "/about/team" ].each do |path|
      get path
      assert_response :success, path
      assert_equal %w[Culture Design], page_props["props"]["footer_topics"].map { |topic| topic["title"] }, path
      assert page_props["props"]["page"]["title"], "the page itself is still there on #{path}"
    end

    get "/no-such-page"
    assert_response :not_found
    assert_equal %w[Culture Design], page_props["props"]["footer_topics"].map { |topic| topic["title"] }
  end

  test "a preview gets the layout's queries" do
    layout("footer_topics" => { "from" => "terms:topics", "fields" => %w[title] })
    match = Nibble::Routing.resolve(@posts.first.uri)

    props = Nibble::PageProps.new(match, request_path: @posts.first.uri, preview: true).build.props
    assert_equal 2, props["footer_topics"].size
  end

  test "a param a layout declares reaches its query and keys the page cache" do
    layout("params" => %w[topic], "picked" => { "from" => "entries:posts", "where" => { "topics" => "$params.topic" }, "fields" => %w[title] })

    get "/about/team", params: { topic: @culture.id }
    assert_equal({ "topic" => @culture.id.to_s }, page_props["props"]["site"]["params"])
    assert_equal [ "Type scales", "Remote work" ].sort, page_props["props"]["picked"].map { |post| post["title"] }.sort

    get "/about/team", params: { topic: @design.id }
    assert_nil response.headers["X-Nibble-Cache"], "another value of a layout's param is another page"
    assert_equal 3, page_props["props"]["picked"].size

    get "/about/team", params: { topic: @culture.id }
    assert_equal "hit", response.headers["X-Nibble-Cache"]
  end

  test "editing an entry a layout lists purges every page that uses the layout" do
    layout("recent" => { "from" => "entries:posts", "limit" => 1, "sort" => "published_at:desc", "fields" => %w[title] })
    get "/about/team"
    assert_includes response.headers["Surrogate-Key"].split, "collection:posts"

    latest = @posts.last
    ok Nibble::Lifecycle.call(latest, :save, { "title" => "Type scales, again" }, actor: Nibble::Principal.system)
    ok Nibble::Lifecycle.call(latest.reload, :publish, actor: Nibble::Principal.system)
    Nibble::Events.dispatch_pending

    get "/about/team"
    assert_nil response.headers["X-Nibble-Cache"]
    assert_equal [ "Type scales, again" ], page_props["props"]["recent"].map { |post| post["title"] }
  end

  test "page.include in the view and the layout together expand the page's own relationship fields" do
    grids, colour = @posts[1], @posts[0]
    ok Nibble::Lifecycle.call(grids, :save, { "related" => [ colour.id.to_s ] }, actor: Nibble::Principal.system)
    ok Nibble::Lifecycle.call(grids.reload, :publish, actor: Nibble::Principal.system)
    write("views/posts/show.yml", { "page" => { "include" => %w[topics] } })
    layout("page" => { "include" => %w[related] })

    get grids.uri
    page = page_props["props"]["page"]
    assert_equal [ "Design" ], page["topics"].map { |topic| topic["title"] }
    assert_equal @design.uuid, page["topics"].first["uuid"], "an included term is the whole record, not its summary"
    assert_equal colour.uuid, page["related"].first["uuid"]
  end

  test "a page key with a source is still a query, as it was before page meant the page itself" do
    write("views/posts/show.yml", { "page" => { "from" => "entries:posts", "limit" => 1, "fields" => %w[title] } })

    get @posts.first.uri
    assert_kind_of Array, page_props["props"]["page"]
  end

  test "children lists each entry's published children in tree order, one level down" do
    careers = page({ "title" => "Careers", "parent_id" => @about.id })
    ok Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "pages"), :create, { "title" => "Secret", "parent_id" => @about.id }, actor: Nibble::Principal.system)
    history = page({ "title" => "History", "parent_id" => @team.id })
    @team.update_columns(position: 2)
    careers.update_columns(position: 1)
    Nibble::PageCache.store.clear
    layout("menu" => { "from" => "entries:pages", "where" => { "parent_id" => { "null" => true } }, "include" => %w[children], "fields" => %w[title uri] })

    get "/blog"
    menu = page_props["props"]["menu"].index_by { |item| item["title"] }
    assert_equal %w[Careers Team], menu["About"]["children"].map { |child| child["title"] }, "tree order, and never a draft"
    assert_equal [], menu["Blog"]["children"]
    assert_not menu["About"]["children"].last.key?("children"), "#{history.title} is deeper than a page goes"
  end

  # Layouts that share a header share its queries by naming the layout they build on, not by copying them.
  test "a layout that extends another gets its queries, params and page includes, and overrides by name" do
    @themes.join("starter", "layouts").mkpath
    @themes.join("starter", "layouts", "docs.vue").write("<template><slot /></template>\n")
    layout("params" => %w[topic], "recent" => { "from" => "entries:posts", "limit" => 1 }, "topics" => { "from" => "terms:topics" }, "page" => { "include" => %w[topics] })
    write("layouts/docs.yml", { "extends" => "default", "topics" => { "from" => "terms:topics", "limit" => 1 }, "pages" => { "from" => "entries:pages" }, "page" => { "include" => %w[related] } })

    sidecar = Nibble::Views.layout_sidecar("docs")
    assert_equal %w[pages recent topics], sidecar.queries.keys.sort
    assert_equal 1, sidecar.queries["topics"]["limit"], "the layout's own query wins over the one it extends"
    assert_equal %w[topic], sidecar.params
    assert_equal %w[topics related].sort, sidecar.page_include.sort
    assert_equal %w[recent topics], Nibble::Views.layout_sidecar("default").queries.keys.sort, "extending doesn't change the base"
  end
end
