require "test_helper"

class Admin::CpScreensTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]
  def component = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["component"]

  test "globals are edited per set through the lifecycle" do
    get "/admin/globals"
    assert_includes props["sets"].map { |set| set["handle"] }, "site"

    get "/admin/globals/site/edit"
    assert_equal "admin/globals/Edit", component

    patch "/admin/globals/site", params: { global: { name: "Nibble Demo" } }
    assert_equal "Nibble Demo", Nibble::Records::GlobalSet.find_by!(handle: "site").data["name"]
  end

  test "a global set's first save creates it, because the editor posts when no record exists yet" do
    post "/admin/globals/integrations", params: { global: { captcha_site_key: "site-key" } }

    assert_equal "site-key", Nibble::Records::GlobalSet.find_by!(handle: "integrations").data["captcha_site_key"]
  end

  test "an invalid global reports its error and saves nothing" do
    patch "/admin/globals/site", params: { global: { name: "" } }
    assert_match "required", session[:inertia_errors].with_indifferent_access[:name]
    assert_nil Nibble::Records::GlobalSet.find_by(handle: "site")
  end

  test "the navigation builder lists linkable records and saves a tree" do
    doc = create_entry("docs", { "title" => "Guide", "body" => "Body" })
    lifecycle(doc, :submit)
    lifecycle(doc.reload, :approve)
    lifecycle(doc.reload, :publish)

    get "/admin/navigation/docs_menu/edit"
    assert_equal [ doc.id ], props["records"].map { |record| record["id"] }
    assert_equal [ "entry", "docs", "Docs" ], props["records"].first.values_at("type", "group", "group_title"),
      "the link editor offers one link type per collection, named by its title"

    patch "/admin/navigation/docs_menu", params: { tree: [ { title: "Guide", link: { type: "entry", id: doc.id }, children: [] } ] }
    tree = Nibble::Records::NavigationTree.find_by!(handle: "docs_menu")
    assert_equal [ [ "entry", doc.id ] ], tree.tree.map { |node| [ node["type"], node["id"] ] }
  end

  test "a link the navigation doesn't allow is refused" do
    article = create_entry("articles", { "title" => "Not allowed here" })

    patch "/admin/navigation/docs_menu", params: { tree: [ { title: "Nope", link: { type: "entry", id: article.id }, children: [] } ] }
    assert_match "doesn't allow", session[:inertia_errors].with_indifferent_access[:tree]
  end

  test "trash lists deleted records, restores them and purges for good" do
    entry = create_entry("articles", { "title" => "Gone" })
    lifecycle(entry, :trash)

    get "/admin/trash"
    assert_equal [ "Gone" ], props["items"].map { |item| item["title"] }

    post "/admin/trash/entry-#{entry.id}/restore"
    assert_not entry.reload.trashed?

    lifecycle(entry.reload, :trash)
    delete "/admin/trash/entry-#{entry.id}/purge"
    assert_not Nibble::Records::Entry.exists?(entry.id)
  end

  test "redirects are managed from the CP and stay single-hop" do
    post "/admin/redirects", params: { redirect: { from: "/old", to: "/new", status: 301 } }
    assert_equal "/new", Nibble::Records::Redirect.find_by!(from: "/old").to

    post "/admin/redirects", params: { redirect: { from: "/new", to: "/newest", status: 301 } }
    assert_equal "/newest", Nibble::Records::Redirect.find_by!(from: "/old").to, "chains collapse on save"

    post "/admin/redirects", params: { redirect: { from: "/newest", to: "/old", status: 301 } }
    assert_match "loop", session[:inertia_errors].with_indifferent_access[:to]
  end

  test "the 404 monitor lists missing paths for redirect suggestions" do
    Nibble::Records::NotFound.record("/gone", referrer: "https://example.test/")

    get "/admin/404s"
    assert_equal [ "/gone" ], props["paths"].map { |row| row["path"] }

    delete "/admin/404s/#{Nibble::Records::NotFound.find_by!(path: '/gone').id}"
    assert_equal 0, Nibble::Records::NotFound.count
  end

  test "utilities report schema problems, search indexes and system counts" do
    create_entry("articles", { "title" => "Counted" })

    get "/admin/utilities/search"
    assert_includes props["search"]["indexes"].map { |index| index["handle"] }, "site"

    get "/admin/utilities/health"
    assert_equal 1, props["system"]["entries"]

    post "/admin/utilities/rebuild_search"
    assert_redirected_to "/admin/utilities/search"
  end

  test "the utilities index lists every utility, and each one opens" do
    get "/admin/utilities"
    urls = props["utilities"].map { |utility| utility["url"] }

    assert_equal Nibble::Cp::Utilities::LIST.size, urls.size
    urls.each do |url|
      get url
      assert_response :success, "#{url} is listed but doesn't open"
    end
  end

  test "every link the sidebar hands out opens" do
    create_entry("articles", { "title" => "Something to list" })
    urls = Nibble::Cp::Navigation.for(users(:editor)).flat_map { |section| section["items"] }
      .flat_map { |item| [ item["url"], *Array(item["children"]).map { |child| child["url"] } ] }

    urls.each do |url|
      get url
      assert_response :success, "#{url} is in the menu but doesn't open"
    end
  end

  test "every link an index screen hands out opens its editor" do
    get "/admin/globals"
    get props["sets"].first["url"]
    assert_equal "admin/globals/Edit", component

    get "/admin/navigation"
    get props["menus"].first["url"]
    assert_equal "admin/navigation/Edit", component

    get "/admin/blueprints"
    get "/admin/blueprints/#{props['rows'].first['handle']}"
    assert_equal "admin/blueprints/Show", component, "blueprint handles contain a dot, which routing must not read as a format"
  end

  test "a cache tag is purged on its own, and the audit log is readable" do
    entry = create_entry("articles", { "title" => "Audited" })

    get "/admin/utilities/audit"
    row = props["audit"].find { |item| item["action"] == "record.created" }

    assert row, "the log is what makes a change traceable"
    assert_includes row["changed"], "title", "an entry with no changed fields tells no one anything"

    post "/admin/utilities/purge_cache", params: { tags: "entry:#{entry.id}, collection:articles" }
    assert_redirected_to "/admin/utilities/cache"
    assert_equal "Purged entry:#{entry.id} and collection:articles.", flash[:notice]

    post "/admin/utilities/purge_cache", params: { tags: "  " }
    assert_equal "Name at least one cache tag.", flash[:alert], "clearing everything by accident is the failure to avoid"
  end

  test "authors can't reach tools they have no ability for" do
    sign_in_as users(:author)

    get "/admin/globals"
    assert_response :forbidden
    get "/admin/redirects"
    assert_response :forbidden
    get "/admin/utilities"
    assert_response :forbidden
  end
end
