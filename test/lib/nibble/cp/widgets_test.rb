require "test_helper"

class Nibble::Cp::WidgetsTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  test "widgets someone isn't allowed to use stay off their dashboard even if their saved layout names them" do
    Nibble::UserPreferences.set!(users(:author), "dashboard.widgets", [
      { "type" => "missing_pages", "width" => 50 }, { "type" => "site_health", "width" => 50 },
      { "type" => "awaiting_review", "width" => 50 }, { "type" => "recent_entries", "width" => 50 }
    ])

    assert_equal [ "recent_entries" ], Nibble::Cp::Widgets.layout(users(:author)).map { |widget| widget["type"] }
    assert_equal [ "recent_entries" ], Nibble::Cp::Widgets.data(users(:author)).keys
    assert_not_includes Nibble::Cp::Widgets.available(users(:author)).map { |widget| widget["type"] }, "site_health"
  end

  test "the published tile counts the last 30 days and nothing older, so its number matches the period it names" do
    travel_to Time.zone.parse("2026-09-19 12:00") do
      { "Recent" => 2.days.ago, "Earlier" => 40.days.ago, "Ancient" => 90.days.ago }.each do |title, at|
        publish_entry(create_entry("articles", { "title" => title }), "published_at" => at.utc.iso8601)
      end

      tile = Nibble::Cp::Widgets.data(users(:editor))["overview"]["tiles"].find { |item| item["key"] == "published" }
      assert_equal 1, tile["total"], "only Recent falls in the last 30 days"
      assert_equal 30, tile["series"].size
      assert_equal 1, tile["series"][-3], "two days ago lands in the third-last daily bucket"
    end
  end

  test "reviewers only see entries waiting in collections they can approve" do
    reviewer = Nibble::User.create!(email_address: "reviewer@example.com", password: "Test-Password-1", name: "Reviewer")
    reviewer.roles << Nibble::Role.create!(handle: "doc_reviewer", title: "Doc reviewer", abilities: %w[entries.*.view workflow.approve.docs])
    doc = create_entry("docs", { "title" => "Needs eyes" })
    assert lifecycle(doc, :submit).ok?
    create_entry("articles", { "title" => "Just a draft" })

    items = Nibble::Cp::Widgets.data(reviewer).fetch("awaiting_review")["items"]
    assert_equal [ "Needs eyes" ], items.map { |item| item["title"] }
    assert items.first["since"].present?
    assert_not Nibble::Cp::Widgets.layout(users(:author)).any? { |widget| widget["type"] == "awaiting_review" }
  end

  test "content mix counts approved entries as still in review so nothing drops out of the totals" do
    doc = create_entry("docs", { "title" => "Approved doc" })
    lifecycle(doc, :submit)
    lifecycle(doc, :approve)
    create_entry("docs", { "title" => "Draft doc" })

    docs = Nibble::Cp::Widgets.data(users(:editor))["content_mix"]["collections"].find { |item| item["handle"] == "docs" }
    assert_equal 1, docs["counts"]["in_review"]
    assert_equal 1, docs["counts"]["draft"]
    assert_equal 2, docs["total"]
  end
end
