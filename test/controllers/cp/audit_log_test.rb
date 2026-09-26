require "test_helper"

class Nibble::Cp::AuditLogTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def ids = page["props"]["audit"].map { |row| row["id"] }
  def next_cursor = page.dig("scrollProps", "audit", "nextPage")

  def record(count) = count.times { |index| Nibble::AuthLog.record("signed_in", user: users(:editor), ip: "10.0.0.#{index}") }

  test "the log opens on the newest 25 and says where the next page starts" do
    record(30)

    get "/cp/utilities/audit"

    assert_equal 25, ids.size
    assert_equal ids.sort.reverse, ids, "newest first"
    assert_equal ids.last, next_cursor
  end

  test "following the cursor walks the whole log with nothing repeated or skipped" do
    record(60)
    seen = []

    get "/cp/utilities/audit"
    seen.concat(ids)
    while next_cursor
      get "/cp/utilities/audit", params: { before: next_cursor }
      seen.concat(ids)
    end

    assert_equal Nibble::Records::AuditEntry.order(id: :desc).pluck(:id), seen
  end

  test "an entry recorded between loads doesn't shift the next page" do
    record(30)
    get "/cp/utilities/audit"
    first = ids
    cursor = next_cursor

    record(1)
    get "/cp/utilities/audit", params: { before: cursor }

    assert_empty first & ids, "no row appears twice"
    assert_equal first.last - 1, ids.first, "the next page starts right where the first ended"
  end

  test "the last page says there's nothing older" do
    record(3)

    get "/cp/utilities/audit"

    assert_nil next_cursor
  end
end
