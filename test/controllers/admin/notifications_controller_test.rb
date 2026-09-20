require "test_helper"

class Admin::NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:editor)
    @mine = Nibble::Records::Notification.create!(user_id: users(:editor).id, kind: "comment.mentioned", data: { "title" => "Mine" })
    @other = Nibble::Records::Notification.create!(user_id: users(:editor).id, kind: "workflow.approved", data: { "title" => "Also mine" })
    @theirs = Nibble::Records::Notification.create!(user_id: users(:author).id, kind: "workflow.approved", data: { "title" => "Theirs" })
  end

  test "removing one notification leaves the rest of the list and the unread count in step" do
    delete "/admin/notifications/#{@mine.id}", as: :json

    assert_response :success
    assert_equal [ "Also mine" ], response.parsed_body["notifications"].map { |row| row["title"] }
    assert_equal 1, response.parsed_body["unread"]
  end

  test "clearing all only empties the signed-in person's list" do
    delete "/admin/notifications", as: :json

    assert_response :success
    assert_empty response.parsed_body["notifications"]
    assert Nibble::Records::Notification.exists?(@theirs.id), "someone else's notifications must survive"
  end

  test "nobody can remove another person's notification" do
    delete "/admin/notifications/#{@theirs.id}", as: :json

    assert_response :not_found
    assert Nibble::Records::Notification.exists?(@theirs.id)
  end
end
