require "test_helper"

class Nibble::Cp::ListingTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def listing(user = users(:editor)) = Nibble::Cp::Listing.new(Nibble.schema.collection("articles"), user:, params: ActionController::Parameters.new({}))

  test "saved columns come back in the order they were arranged, and reset can still find the defaults" do
    UserPreferences.set!(users(:editor), "listings.collections_articles.columns", %w[status image title])

    columns = listing.props["columns"]
    assert_equal %w[status image title], columns.select { |column| column["visible"] }.map { |column| column["handle"] }
    assert_equal %w[status image title], columns.first(3).map { |column| column["handle"] }
    assert columns.find { |column| column["handle"] == "title" }["default"]
    assert_not columns.find { |column| column["handle"] == "image" }["default"], "images stay hidden until someone asks for them"
  end

  test "an image column carries thumbnails the table can draw, not asset titles" do
    UserPreferences.set!(users(:editor), "listings.collections_articles.columns", %w[title image])
    asset = create_asset({ "title" => "Hero" })
    create_entry("articles", { "title" => "With a picture", "image" => [ { "asset" => asset.id.to_s } ] })

    row = listing.props["rows"].find { |item| item["title"] == "With a picture" }
    assert_equal [ [ asset.thumbnail_url, "Hero" ] ], row["image"].map { |item| item.values_at("thumbnail", "title") }
    assert row["image"].first["url"].present?, "each thumbnail links to the file"
  end

  test "a page of rows costs the same handful of queries however many rows it holds" do
    UserPreferences.set!(users(:editor), "listings.collections_articles.columns", %w[title image tags])
    tag = create_term("Design")
    count = lambda do
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { listing.props }
      queries
    end
    add = ->(title) { create_entry("articles", { "title" => title, "image" => [ { "asset" => create_asset.id.to_s } ], "tags" => [ tag.id.to_s ] }) }

    add.("First")
    count.call
    few = count.call
    5.times { |index| add.("More #{index}") }

    assert_operator count.call, :<=, few, "images and tags are fetched once per page, not once per row"
  end
end
