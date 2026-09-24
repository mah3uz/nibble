require "test_helper"

class FormNotificationsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  VALUES = { email: "ada@example.test", topics: %w[sales support], message: "Call me" }.freeze

  setup do
    @handled = handled = []
    Nibble::Forms.register_handler("test.enquiry", ->(form:, data:, submission:) { handled << [ form.handle, data, submission&.id ] })
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { ActiveSupport::Cache::MemoryStore.new }
  end

  teardown do
    Nibble::Forms.handlers.delete("test.enquiry")
    Nibble::Forms::Submit.rate_limit_store = @rate_limit_store
  end

  def submit(values = VALUES) = post("/forms/enquiry", params: values, as: :json)
  def submission = Nibble::Records::FormSubmission.sole

  test "each notify entry emails its recipients, with only its fields and the visitor as reply-to" do
    perform_enqueued_jobs { submit }
    assert_response :created

    mails = ActionMailer::Base.deliveries.index_by { |mail| mail.to.first }
    team, topics = mails.values_at("sales@example.test", "a@example.test")
    assert_equal [ [ "sales@example.test" ], [ "ada@example.test" ], "New submission: Enquiry" ], [ team.to, team.reply_to, team.subject ]
    assert_includes team.text_part.body.to_s, "Call me"
    assert_includes team.text_part.body.to_s, "sales, support"
    assert_includes team.html_part.body.to_s, "Reply to this email to answer them at ada@example.test"

    assert_equal [ [ "a@example.test", "b@example.test" ], "Topics" ], [ topics.to, topics.subject ]
    assert_includes topics.text_part.body.to_s, "Topics"
    assert_not_includes topics.html_part.body.to_s, "Call me", "fields limits what leaves the site by email"
  end

  test "emails come from the sender in the Integrations settings, or a noreply address until one is set" do
    perform_enqueued_jobs { submit }
    assert_equal [ "noreply@example.com" ], ActionMailer::Base.deliveries.last.from

    record = Nibble::Records::GlobalSet.find_or_initialize_by(handle: "integrations", locale: "en")
    assert lifecycle(record, :save, { "mail_from_name" => "Nibble Team", "mail_from_address" => "hello@example.test" }).ok?
    assert lifecycle(record, :save, { "mail_from_address" => "not an address" }).invalid?
    ActionMailer::Base.deliveries.clear
    perform_enqueued_jobs { submit }
    assert_equal [ "Nibble Team <hello@example.test>" ], ActionMailer::Base.deliveries.map { |mail| mail[:from].to_s }.uniq
  end

  test "a reply-to that isn't an email address is left off rather than put into the header" do
    perform_enqueued_jobs { submit VALUES.merge(email: "ada@example.test\r\nBcc: all@example.test") }
    assert_response :unprocessable_entity
    perform_enqueued_jobs { submit VALUES.merge(email: nil) }
    team = ActionMailer::Base.deliveries.find { |mail| mail.to == [ "sales@example.test" ] }
    assert_nil team.reply_to
    assert_not_includes team.text_part.body.to_s, "Reply to this email", "a reply would reach nobody, so the email must not suggest one"
  end

  test "people who can see form submissions get an in-app notification, others don't" do
    perform_enqueued_jobs(only: Nibble::Jobs::NotifySubmission) { submit }

    notified = Nibble::Records::Notification.where(kind: "form.submitted")
    assert_equal [ users(:admin).id, users(:editor).id ].sort, notified.pluck(:user_id).sort
    assert_equal [ [ submission.id, "Enquiry" ] ], notified.map { |item| [ item.subject_id, item.data["title"] ] }.uniq
  end

  test "the form's registered handler runs after the submission is stored" do
    submit
    assert_empty @handled, "handlers run as jobs, not during the visitor's request"
    perform_enqueued_jobs(only: Nibble::Jobs::HandleSubmission)
    assert_equal [ [ "enquiry", submission.data, submission.id ] ], @handled
  end

  test "spam, invalid and remotely rejected submissions notify nobody" do
    submit VALUES.merge(_nibble_hp: "bot")
    submit VALUES.merge(topics: [ "billing" ])
    assert_no_enqueued_jobs(only: [ Nibble::Jobs::NotifySubmission, Nibble::Jobs::HandleSubmission ])
  end

  test "a form without notify, cp_notify or a handler enqueues no follow-up" do
    post "/forms/contact", params: { name: "Ada", email: "ada@example.test", message: "Hi" }, as: :json
    assert_response :created
    assert_no_enqueued_jobs(only: [ Nibble::Jobs::NotifySubmission, Nibble::Jobs::HandleSubmission ])
  end
end
