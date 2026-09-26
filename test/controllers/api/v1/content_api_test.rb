require "test_helper"

class Api::V1::ContentApiTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup do
    @token = Nibble::ApiToken.issue(name: "Site", scopes: %w[read]).last
    @preview_token = Nibble::ApiToken.issue(name: "Preview", scopes: %w[preview]).last
  end

  def auth(token = @token) = { "Authorization" => "Bearer #{token}" }
  def body = JSON.parse(response.body)

  def published(title = "Live")
    publish_entry(create_entry("articles", { "title" => title })).reload
  end

  test "every request needs a token" do
    get "/api/v1/collections/articles/entries"
    assert_response :unauthorized

    get "/api/v1/collections/articles/entries", headers: { "Authorization" => "Bearer nib_#{'0' * 48}" }
    assert_response :unauthorized
  end

  test "a read token sees published entries of an exposed collection and nothing else" do
    published("Live one")
    create_entry("articles", { "title" => "Still a draft" })

    get "/api/v1/collections/articles/entries", headers: auth

    assert_response :success
    assert_equal [ "Live one" ], body["data"].map { |entry| entry["title"] }
    assert_equal "max-age=0, private, must-revalidate", response.headers["Cache-Control"]
    assert response.headers["ETag"].present?
  end

  test "a preview token can ask for drafts, a read token can't" do
    published("Live one")
    create_entry("articles", { "title" => "Still a draft" })

    get "/api/v1/collections/articles/entries", params: { preview: 1 }, headers: auth(@preview_token)
    assert_equal [ "Live one", "Still a draft" ], body["data"].map { |entry| entry["title"] }.sort

    get "/api/v1/collections/articles/entries", params: { preview: 1 }, headers: auth
    assert_equal [ "Live one" ], body["data"].map { |entry| entry["title"] }
  end

  test "the API answers with the same shape the theme gets for that record" do
    entry = published("Shared shape")

    get "/api/v1/entries/#{entry.uuid}", headers: auth

    theme = Nibble::Presenter.present([ entry ]).first
    assert_equal theme, body["data"]
  end

  test "filters, sorting, paging and field picking work as query params" do
    published("Bravo")
    published("Alpha")

    get "/api/v1/collections/articles/entries", params: { sort: "-title", "page" => { "size" => 1 } }, headers: auth
    assert_equal [ "Bravo" ], body["data"].map { |entry| entry["title"] }
    assert_equal({ "current_page" => 1, "per_page" => 1, "total" => 2, "last_page" => 2 }, body["meta"]["page"])

    get "/api/v1/collections/articles/entries", params: { filter: { title: "Alpha" }, fields: "title,slug" }, headers: auth
    assert_equal [ "Alpha" ], body["data"].map { |entry| entry["title"] }
  end

  test "a bad query is answered with what's wrong, not a 500" do
    get "/api/v1/collections/articles/entries", params: { sort: "-nonsense" }, headers: auth

    assert_response :bad_request
    assert_match "sort", body["errors"].first["detail"]
  end

  test "an unchanged response comes back as 304, so clients can cache it" do
    published

    get "/api/v1/collections/articles/entries", headers: auth
    etag = response.headers["ETag"]

    get "/api/v1/collections/articles/entries", headers: auth.merge("If-None-Match" => etag)
    assert_response :not_modified
  end

  test "a path resolves to the record that answers it" do
    entry = published("Routed")

    get "/api/v1/routes", params: { path: entry.uri }, headers: auth

    assert_equal "entry", body["data"]["kind"]
    assert_equal entry.uuid, body["data"]["uuid"]
  end

  test "the schema endpoint describes exposed collections and their fields" do
    get "/api/v1/schema", headers: auth

    handles = body["data"]["collections"].map { |item| item["handle"] }
    assert_includes handles, "articles"
    assert body["data"]["collections"].first["blueprints"].first["fields"].any?
  end

  test "using a token records when it was last used" do
    token = Nibble::ApiToken.find_by!(name: "Site")
    assert_nil token.last_used_at

    get "/api/v1/schema", headers: auth

    assert_not_nil token.reload.last_used_at
  end

  def mark_api_false(load_defaults:)
    blueprint = @nibble_themes.join("records/schema/blueprints/collections/articles/article.yml")
    data = YAML.safe_load(blueprint.read)
    data["tabs"]["main"]["sections"][0]["fields"] << { "handle" => "internal_note", "field" => { "type" => "text", "api" => false } }
    blueprint.write(data.to_yaml)
    global = @nibble_themes.join("site_schema/globals/company.yml")
    global.dirname.mkpath
    global.write({ "schema" => 1, "title" => "Company", "blueprint" => { "title" => "Company", "tabs" => { "main" => { "sections" => [ { "fields" => [
      { "handle" => "name", "field" => { "type" => "text" } },
      { "handle" => "internal_note", "field" => { "type" => "text", "api" => false } } ] } ] } } } }.to_yaml)
    configure_nibble_records(load_defaults:)
    Nibble.reset_schema!
  end

  # The option exists to keep a value off the API; a check on the top level alone would miss a relation leaking it.
  test "a field marked api: false stays out of every API response, nested ones and globals included" do
    mark_api_false(load_defaults: "0.15.0")
    other = published("Other")
    lifecycle(other, :save, { "internal_note" => "margin is thin" })
    lifecycle(other.reload, :publish)
    entry = publish_entry(create_entry("articles", { "title" => "Main", "internal_note" => "secret", "related" => [ other.id.to_s ] })).reload
    lifecycle(Nibble::Records::GlobalSet.new(handle: "company", locale: "en"), :save, { "name" => "Tidewater", "internal_note" => "secret" })

    get "/api/v1/entries/#{entry.uuid}", params: { include: "related" }, headers: auth
    assert_response :success
    assert_not body["data"].key?("internal_note")
    assert_not body["data"]["related"].first.key?("internal_note")

    get "/api/v1/globals/company", headers: auth
    assert_equal "Tidewater", body["data"]["name"]
    assert_not body["data"].key?("internal_note")
  end

  # A behaviour a site would notice ships switched off until the site opts in.
  test "a site that has not raised load_defaults still gets api: false fields" do
    mark_api_false(load_defaults: "0.14.7")
    entry = publish_entry(create_entry("articles", { "title" => "Main", "internal_note" => "secret" })).reload

    get "/api/v1/entries/#{entry.uuid}", headers: auth
    assert_equal "secret", body["data"]["internal_note"]
  end
end
