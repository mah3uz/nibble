require "test_helper"

class Nibble::Subscribers::NotificationsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include NibbleRecordsHelper

  def submit_doc(actor:)
    doc = create_entry("docs", { "title" => "Needs review", "body" => "Body" })
    lifecycle(doc, :submit, actor: actor)
    Nibble::Events.dispatch_pending
    doc.reload
  end

  test "a submission reaches whoever can approve it, and not the person who submitted" do
    doc = submit_doc(actor: users(:author))

    kinds = Nibble::Records::Notification.where(subject_id: doc.id).pluck(:user_id, :kind)

    assert_includes kinds, [ users(:editor).id, "workflow.review_requested" ], "a review nobody is told about waits forever"
    assert_not_includes kinds.map(&:first), users(:author).id, "the submitter already knows they submitted"
  end

  test "the outcome goes back to whoever asked for the review" do
    doc = submit_doc(actor: users(:author))
    Nibble::Records::Notification.delete_all

    lifecycle(doc, :approve, actor: users(:editor))
    Nibble::Events.dispatch_pending

    notification = Nibble::Records::Notification.find_by(user_id: users(:author).id)
    assert_equal "workflow.approved", notification&.kind
    assert_equal "Needs review", notification.data["title"]
  end

  test "email follows the in-app notification unless the person turned it off" do
    assert_emails 1 do
      Nibble::Records::Notification.notify(users(:author).id, "comment.mentioned", title: "Hello")
    end

    UserPreferences.set!(users(:author), "notifications.email", false)

    assert_no_emails do
      Nibble::Records::Notification.notify(users(:author).id, "comment.mentioned", title: "Hello again")
    end
  end

  test "sending an entry back tells the requester it was rejected" do
    doc = submit_doc(actor: users(:author))
    Nibble::Records::Notification.delete_all

    lifecycle(doc, :reject, { "comment" => "Needs sources" }, actor: users(:editor))
    Nibble::Events.dispatch_pending

    notification = Nibble::Records::Notification.find_by(user_id: users(:author).id)
    assert_equal "workflow.rejected", notification&.kind
    assert_equal "Needs sources", notification.data["comment"], "the reason is the useful part of a rejection"
  end
end
