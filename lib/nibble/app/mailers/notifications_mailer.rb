class NotificationsMailer < ApplicationMailer
  SUBJECTS = {
    "workflow.review_requested" => "A review was requested",
    "workflow.approved" => "Your entry was approved",
    "workflow.rejected" => "Your entry was sent back",
    "comment.mentioned" => "You were mentioned",
    "form.submitted" => "New form submission",
    "webhook.disabled" => "A webhook was turned off after repeated failures"
  }.freeze

  def notify(notification)
    @notification = notification
    @user = ::User.find_by(id: notification.user_id) or return
    @title = notification.data["title"]
    @comment = notification.data["comment"]
    mail subject: SUBJECTS.fetch(notification.kind, "Something needs your attention"), to: @user.email_address
  end
end
