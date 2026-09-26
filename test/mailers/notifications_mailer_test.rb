require "test_helper"

class NotificationsMailerTest < ActionMailer::TestCase
  test "a notification email says what happened and leads back to the Control Plane" do
    notification = Nibble::Records::Notification.create!(user_id: users(:author).id, kind: "workflow.rejected",
                                                         data: { "title" => "Launch post", "comment" => "Needs sources" })
    mail = NotificationsMailer.notify(notification)
    body = mail.html_part.body.to_s

    assert_equal "Your entry was sent back", mail.subject
    assert_includes body, "Launch post"
    assert_includes body, "Needs sources", "a rejection without its reason leaves the author guessing"
    assert_includes body, "/cp/notifications", "with nothing to follow, the reader has to find the Control Plane themselves"
  end
end
