require "test_helper"

class Api::V1::ThemeParityTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup { @token = Nibble::ApiToken.issue(name: "Parity", scopes: %w[read]).last }

  def body = JSON.parse(response.body)

  test "a theme view and the API describe the same entry identically" do
    entry = publish_entry(create_entry("articles", { "title" => "Parity", "summary" => "Same both ways" })).reload
    match = Nibble::Routing.resolve(entry.uri)
    theme = Nibble::PageProps.new(match, request_path: entry.uri).build.props["page"]

    get "/api/v1/entries/#{entry.uuid}", headers: { "Authorization" => "Bearer #{@token}" }

    assert_equal theme, body["data"], "the API's data is the presenter payload the theme gets, envelope aside"
  end

  test "a listing answers with the same records a theme query would present" do
    first = publish_entry(create_entry("articles", { "title" => "One" })).reload
    second = publish_entry(create_entry("articles", { "title" => "Two" })).reload
    context = Nibble::Query::Context.public
    result = Nibble::Query.build({ "from" => "entries:articles", "sort" => [ "title:asc" ] }, context).result
    theme = Nibble::Presenter.new(context:).present(result.records)

    get "/api/v1/collections/articles/entries", params: { sort: "title" },
      headers: { "Authorization" => "Bearer #{@token}" }

    assert_equal theme, body["data"]
    assert_equal [ first.uuid, second.uuid ], body["data"].map { |item| item["uuid"] }
  end
end
