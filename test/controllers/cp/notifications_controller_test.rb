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
end
