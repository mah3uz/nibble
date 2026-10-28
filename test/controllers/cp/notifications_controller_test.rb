require "test_helper"

class Nibble::Cp::NotificationsControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  setup do
    sign_in_as users(:editor)
    @mine = Nibble::Records::Notification.create!(user_id: users(:editor).id, kind: "comment.mentioned", data: { "title" => "Mine" })
    @other = Nibble::Records::Notification.create!(user_id: users(:editor).id, kind: "workflow.approved", data: { "title" => "Also mine" })
    @theirs = Nibble::Records::Notification.create!(user_id: users(:author).id, kind: "workflow.approved", data: { "title" => "Theirs" })
  end

  test "removing one notification leaves the rest of the list and the unread count in step" do
    delete "/cp/notifications/#{@mine.id}", as: :json

    assert_response :success
    assert_equal [ "Also mine" ], response.parsed_body["notifications"].map { |row| row["title"] }
    assert_equal 1, response.parsed_body["unread"]
  end

  test "clearing all only empties the signed-in person's list" do
    delete "/cp/notifications", as: :json

    assert_response :success
    assert_empty response.parsed_body["notifications"]
    assert Nibble::Records::Notification.exists?(@theirs.id), "someone else's notifications must survive"
  end

  test "nobody can remove another person's notification" do
    delete "/cp/notifications/#{@theirs.id}", as: :json

    assert_response :not_found
    assert Nibble::Records::Notification.exists?(@theirs.id)
  end

  test "a notification about an entry links to that entry's editor" do
    entry = create_entry("articles", { "title" => "Linked" })
    Nibble::Records::Notification.notify(users(:editor).id, "comment.mentioned", subject: entry, title: "Linked")

    get "/cp/notifications", as: :json

    row = response.parsed_body["notifications"].find { |item| item["title"] == "Linked" }
    assert_equal "/cp/collections/articles/entries/#{entry.id}/edit", row["url"], "a mention you can't click through to is a dead end"
  end

  test "an old notification beyond the first screen is still reachable by paging back from the oldest shown" do
    Nibble::Records::Notification.where(user_id: users(:editor).id).delete_all
    ids = 30.times.map { |n| Nibble::Records::Notification.create!(user_id: users(:editor).id, kind: "comment.mentioned", data: { "title" => "N#{n}" }).id }

    get "/cp/notifications", as: :json
    first = response.parsed_body
    assert_equal 25, first["notifications"].size
    assert first["more"]
    assert_equal 30, first["unread"]

    get "/cp/notifications", params: { before: first["notifications"].last["id"] }, as: :json
    rest = response.parsed_body
    assert_equal ids.first(5).reverse, rest["notifications"].map { |row| row["id"] }
    assert_not rest["more"]
  end

  test "a failing task's notification links to the scheduled tasks page" do
    Nibble::Records::Notification.notify(users(:editor).id, "task.failed", title: "Exchange rates", task: "rates")

    get "/cp/notifications", as: :json

    row = response.parsed_body["notifications"].find { |item| item["title"] == "Exchange rates" }
    assert_equal "/cp/utilities/tasks", row["url"]
  end
end
