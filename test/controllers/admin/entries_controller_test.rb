require "test_helper"

class Admin::EntriesControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { sign_in_as users(:editor) }

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]
  def entries_path(collection = "articles") = "/admin/collections/#{collection}/entries"

  test "the listing is built from the schema: columns, filters and rows from the query engine" do
    create_entry("articles", { "title" => "Kept draft" })
    published = publish_entry(create_entry("articles", { "title" => "Live one" }))

    get "/admin/collections/articles"
    assert_response :success
    listing = props["listing"]

    assert_equal %w[title status published_at], listing["columns"].select { |column| column["visible"] }.map { |column| column["handle"] }
    assert_includes listing["columns"].map { |column| column["handle"] }, "tags", "hidden listable fields stay available in the column picker"
    assert_includes listing["filters"].map { |filter| filter["handle"] }, "status"
    assert_includes listing["rows"].map { |row| row["title"] }, "Kept draft"
    assert_equal "#{entries_path}/#{published.id}/edit", listing["rows"].find { |row| row["title"] == "Live one" }["edit_url"]
    assert_equal "New article", listing["create"]["label"]
  end

  test "listing filters and search narrow the rows" do
    create_entry("articles", { "title" => "Draft about grids" })
    publish_entry(create_entry("articles", { "title" => "Published piece" }))

    get "/admin/collections/articles", params: { status: "draft" }
    assert_equal [ "Draft about grids" ], props["listing"]["rows"].map { |row| row["title"] }

    get "/admin/collections/articles", params: { q: "published" }
    assert_equal [ "Published piece" ], props["listing"]["rows"].map { |row| row["title"] }
  end

  test "creating an entry goes through the lifecycle and lands on its editor" do
    post entries_path, params: { entry: { title: "Written in the CP", summary: "Short" } }

    entry = Nibble::Records::Entry.find_by!(title: "Written in the CP")
    assert_redirected_to "#{entries_path}/#{entry.id}/edit"
    assert_equal [ "draft", "written-in-the-cp" ], [ entry.status, entry.slug ]
    assert_equal "Short", entry.values["summary"]
  end

  test "the key a listing advertises is one the preferences endpoint accepts" do
    get "/admin/collections/articles"
    key = props["listing"]["preference_key"]

    patch "/admin/preferences", params: { key: "listings.#{key}.columns", value: [ "title" ] }

    assert_response :no_content, "customising columns saves nothing when the two sides disagree on the key"
    assert_equal [ "title" ], UserPreferences.get(users(:editor).reload, "listings.#{key}.columns")
  end

  test "a listing exports the rows behind the current filters, not the whole collection" do
    create_entry("articles", { "title" => "Kept draft" })
    publish_entry(create_entry("articles", { "title" => "Live one" }))

    get "/admin/collections/articles.csv", params: { status: "draft" }

    assert_equal "text/csv", response.media_type
    rows = CSV.parse(response.body)
    assert_equal %w[Title Status Date], rows.first
    assert_equal [ "Kept draft" ], rows.drop(1).map(&:first), "exporting rows the filter excluded would mislead"
  end

  test "the editor sends the blueprint, the values and what the user may do" do
    entry = create_entry("articles", { "title" => "Editable" })

    get "#{entries_path}/#{entry.id}/edit"
    assert_response :success

    assert_equal "Editable", props["values"]["title"]
    assert_equal %w[main sidebar], props["blueprint"]["tabs"].map { |tab| tab["handle"] }
    sidebar = props["blueprint"]["tabs"].last["sections"].first["fields"].map { |field| field["handle"] }
    assert_equal %w[slug published_at unpublish_at author_id template], sidebar, "the record's own columns are edited as fields"
    assert_equal true, props["can"]["publish"]
    assert_equal "entry", props["resource_key"]
    assert_equal "/admin/collections/articles/entries/#{entry.id}/preview", props["urls"]["preview"]
  end

  test "a collection's taxonomies each get a terms field, unless its blueprint already has one" do
    doc = create_entry("docs", { "title" => "Guide", "body" => "Body" })

    get "/admin/collections/docs/entries/#{doc.id}/edit"
    sidebar = props["blueprint"]["tabs"].last["sections"].flat_map { |section| section["fields"].map { |field| field["handle"] } }
    assert_includes sidebar, "tags", "the docs collection lists the tags taxonomy"

    article = create_entry("articles", { "title" => "Has its own" })
    get "/admin/collections/articles/entries/#{article.id}/edit"
    handles = props["blueprint"]["tabs"].flat_map { |tab| tab["sections"].flat_map { |section| section["fields"].map { |field| field["handle"] } } }
    assert_equal 1, handles.count("tags"), "a blueprint's own terms field isn't duplicated"
  end

  test "a taxonomy the sidebar adds keeps what's picked in it" do
    tag = create_term("Pricing")
    doc = create_entry("docs", { "title" => "Guide", "body" => "Body" })

    patch "/admin/collections/docs/entries/#{doc.id}", params: { entry: { tags: [ tag.id.to_s ], lock_version: doc.lock_version } }

    assert_equal [ tag.id.to_s ], doc.reload.data["tags"], "a field that shows a choice and then drops it looks like it saved"
  end

  test "a blueprint's own sidebar tab keeps its fields and gains the record's columns" do
    doc = create_entry("docs", { "title" => "Guide", "body" => "Body" })

    get "/admin/collections/docs/entries/#{doc.id}/edit"
    tabs = props["blueprint"]["tabs"]

    assert_equal 1, tabs.count { |tab| tab["handle"] == "sidebar" },
                 "a second tab under the same handle would hide one of the two from the editor"
    sidebar = tabs.last["sections"].flat_map { |section| section["fields"].map { |field| field["handle"] } }
    assert_includes sidebar, "byline", "the blueprint's own sidebar field"
    assert_includes sidebar, "slug", "and the record's own columns alongside it"
  end

  test "saving a live entry stages a draft; publishing applies it" do
    entry = publish_entry(create_entry("articles", { "title" => "Live" }))

    patch "#{entries_path}/#{entry.id}", params: { entry: { title: "Edited", lock_version: entry.lock_version } }
    assert_equal "Live", entry.reload.title, "the live version must not change on save"
    assert_equal "Edited", entry.draft.data["title"]

    post "#{entries_path}/#{entry.id}/publish", params: { entry: { lock_version: entry.reload.lock_version } }
    assert_equal "Edited", entry.reload.title
    assert_nil entry.draft
  end

  test "the live preview renders unsaved values posted as JSON, and saves nothing" do
    entry = publish_entry(create_entry("articles", { "title" => "Live" }))

    post "#{entries_path}/#{entry.id}/preview", params: { entry_json: { title: "Typed but unsaved", summary: "Short" }.to_json }
    assert_response :success
    assert_includes response.body, "Typed but unsaved"
    assert_equal [ "Live", nil ], [ entry.reload.title, entry.draft ]
  end

  test "validation errors come back keyed by field, and nothing is saved" do
    entry = create_entry("articles", { "title" => "Fine" })

    patch "#{entries_path}/#{entry.id}", params: { entry: { summary: "far too long for the twenty character limit", lock_version: entry.lock_version } }
    assert_match "must not be greater than 20", session[:inertia_errors].with_indifferent_access[:summary]
    assert_nil entry.reload.values["summary"]
  end

  test "a stale lock_version is reported as a conflict instead of overwriting" do
    entry = create_entry("articles", { "title" => "Mine" })
    stale = entry.lock_version
    lifecycle(entry, :save, { "title" => "Colleague's" })

    patch "#{entries_path}/#{entry.id}", params: { entry: { title: "Mine again", lock_version: stale } }
    assert_match "Someone saved this", session[:inertia_errors].with_indifferent_access[:lock_version]
    assert_equal "Colleague's", entry.reload.title
  end

  test "review workflow actions move the entry and are refused out of order" do
    doc = create_entry("docs", { "title" => "Guide", "body" => "Body" })

    post "/admin/collections/docs/entries/#{doc.id}/publish"
    assert_equal "draft", doc.reload.status, "publishing needs approval first"

    post "/admin/collections/docs/entries/#{doc.id}/submit"
    assert_equal "in_review", doc.reload.status
    post "/admin/collections/docs/entries/#{doc.id}/approve"
    assert_equal "approved", doc.reload.status
    post "/admin/collections/docs/entries/#{doc.id}/publish"
    assert_equal "published", doc.reload.status
  end

  test "authors only reach their own entries, and can't publish" do
    mine = create_entry("articles", { "title" => "Mine" }, actor: users(:author))
    theirs = create_entry("articles", { "title" => "Theirs" }, actor: users(:editor))
    sign_in_as users(:author)

    patch "#{entries_path}/#{mine.id}", params: { entry: { title: "Updated", lock_version: mine.lock_version } }
    assert_equal "Updated", mine.reload.title

    patch "#{entries_path}/#{theirs.id}", params: { entry: { title: "Hijacked", lock_version: theirs.lock_version } }
    assert_response :forbidden
    assert_equal "Theirs", theirs.reload.title

    post "#{entries_path}/#{mine.id}/publish"
    assert_response :forbidden
  end

  test "bulk actions run through the lifecycle for every selected row" do
    first = create_entry("articles", { "title" => "One" })
    second = create_entry("articles", { "title" => "Two" })

    post "/admin/actions", params: { resource: "collections.articles", handle: "trash", ids: [ first.id, second.id ] }
    assert first.reload.trashed?
    assert second.reload.trashed?
  end

  test "a bulk action nobody is allowed to run changes nothing" do
    entry = create_entry("articles", { "title" => "One" })
    sign_in_as users(:author)

    post "/admin/actions", params: { resource: "collections.articles", handle: "trash", ids: [ entry.id ] }
    assert_response :forbidden
    assert_not entry.reload.trashed?
  end
end
