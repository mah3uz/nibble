require "test_helper"

class FormNotificationTemplatesTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  Submission = Nibble::Records::FormSubmission

  setup do
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { ActiveSupport::Cache::MemoryStore.new }
    write("globals/contact.yml", "title" => "Contact", "blueprint" => { "title" => "Contact", "tabs" => { "main" => { "sections" => [ { "fields" => [
      { "handle" => "email", "field" => { "type" => "text", "input_type" => "email" } },
      { "handle" => "thanks", "field" => { "type" => "text" } }
    ] } ] } } })
    write("forms/help.yml", "title" => "Help", "success" => { "message" => "{global.contact.thanks}" },
      "notify" => [
        { "to" => "{global.contact.email}", "subject" => "{form.title} from {field.name}", "message" => "Hello <b>team</b>, {field.name} wrote in.", "reply_to" => "email" },
        { "to" => "{field.email}", "subject" => "We got it, {field.name}", "message" => "Thanks {field.name}." },
        { "to" => "support@example.test", "if" => { "topic" => "support" } },
        { "to" => "sales@example.test", "if" => { "topic" => "sales" } }
      ],
      "fields" => [ { "handle" => "name", "field" => { "type" => "text" } },
                    { "handle" => "email", "field" => { "type" => "text", "input_type" => "email" } },
                    { "handle" => "topic", "field" => { "type" => "select", "options" => %w[support sales] } } ])
    Nibble.reset_schema!
    Nibble::Records::GlobalSet.create!(handle: "contact", locale: "en", data: { "email" => "desk@example.test", "thanks" => "We'll reply within a day." })
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def write(relative, content)
    path = @nibble_themes.join("records", "schema", relative)
    FileUtils.mkdir_p(path.dirname)
    path.write(content.to_yaml)
  end

  def submit(values = {}) = post("/forms/help", params: { name: "Ada", email: "ada@example.test", topic: "support" }.merge(values), as: :json)
  def mail_to(address) = ActionMailer::Base.deliveries.find { |mail| mail.to.include?(address) }
  def rows = Submission.sole.deliveries.index_by { |row| row["key"] }

  test "subject and message merge the visitor's words escaped, so a visitor can't inject markup or headers into staff mail" do
    perform_enqueued_jobs { submit(name: "<i>Ada</i>\r\nBcc: x@example.test") }

    desk = mail_to("desk@example.test")
    assert_equal "Help from <i>Ada</i> Bcc: x@example.test", desk.subject
    assert_not_includes desk.html_part.body.to_s, "<b>team</b>"
    assert_includes desk.html_part.body.to_s, "Hello &lt;b&gt;team&lt;/b&gt;, &lt;i&gt;Ada&lt;/i&gt;"
    assert_nil desk.header["Bcc"]
  end

  test "to: {field.email} writes to the visitor, and an invalid address skips that email and says why" do
    perform_enqueued_jobs { submit }
    assert_includes mail_to("ada@example.test").text_part.body.to_s, "Thanks Ada."
    assert_equal "sent", rows["notify.1"]["status"]

    ActionMailer::Base.deliveries.clear
    Submission.delete_all
    perform_enqueued_jobs { submit(email: "") }
    assert_nil ActionMailer::Base.deliveries.find { |mail| mail.subject.start_with?("We got it") }
    assert_equal "skipped", rows["notify.1"]["status"]
    assert_match(/no valid recipient/, rows["notify.1"]["error"])
    assert_equal "sent", rows["notify.0"]["status"], "the other notifications still go"
  end

  test "to: {global.contact.email} follows the global, so an editor can change the recipient" do
    perform_enqueued_jobs { submit }
    assert mail_to("desk@example.test")

    Nibble::Records::GlobalSet.find_by!(handle: "contact").update!(data: { "email" => "priya@example.test" })
    ActionMailer::Base.deliveries.clear
    perform_enqueued_jobs { submit }
    assert mail_to("priya@example.test")
    assert_nil mail_to("desk@example.test")
  end

  test "if: sends support to support@ and sales to sales@ only" do
    perform_enqueued_jobs { submit(topic: "support") }
    assert mail_to("support@example.test")
    assert_nil mail_to("sales@example.test")

    ActionMailer::Base.deliveries.clear
    Submission.delete_all
    perform_enqueued_jobs { submit(topic: "sales") }
    assert mail_to("sales@example.test")
    assert_nil mail_to("support@example.test")
    assert_nil rows["notify.2"], "an email that didn't apply is not an attempt"
  end

  test "the success message can come from a global" do
    submit
    assert_equal "We'll reply within a day.", response.parsed_body["message"]
  end

  test "each send is recorded with who it went to, and a failure keeps the error" do
    perform_enqueued_jobs { submit }
    row = rows["notify.0"]
    assert_equal [ "desk@example.test", "sent", "email" ], row.values_at("target", "status", "mode")
    assert_equal "ada@example.test", rows["notify.1"]["target"], "the resolved address, not the placeholder"
    assert_equal "{field.email}", rows["notify.1"]["configured"]

    Submission.delete_all
    Nibble::FormsMailer.define_singleton_method(:submission) { |*| raise "SMTP down" }
    begin
      perform_enqueued_jobs { submit }
    ensure
      Nibble::FormsMailer.singleton_class.remove_method(:submission)
    end
    assert_equal [ "failed", "SMTP down" ], rows["notify.0"].values_at("status", "error")
    assert_equal "received", Submission.sole.status, "an email failure doesn't change the delivery status of the submission"
  end

  test "resend sends the emails again, records them, audits it, and needs edit permission" do
    perform_enqueued_jobs { submit }
    ActionMailer::Base.deliveries.clear

    path = "/cp/forms/help/submissions/#{Submission.sole.id}/resend_notifications"
    sign_in_as users(:author)
    perform_enqueued_jobs { post path, as: :json }
    assert_response :forbidden
    assert_empty ActionMailer::Base.deliveries

    sign_in_as users(:editor)
    perform_enqueued_jobs { post path }
    assert_equal 3, ActionMailer::Base.deliveries.size
    assert_equal 2, rows["notify.0"]["attempts"]
    assert Nibble::Records::AuditEntry.exists?(action: "form.notifications_resent", subject_id: Submission.sole.id)
  end

  test "the submission page offers to send notifications again only to someone who can edit, and never for spam" do
    perform_enqueued_jobs { submit }
    path = "/cp/forms/help/submissions/#{Submission.sole.id}"
    can_resend = -> { get(path) && JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]["can_resend_notifications"] }

    sign_in_as users(:editor)
    assert can_resend.call

    Submission.sole.update!(status: "spam")
    assert_not can_resend.call, "spam sent nothing, so there is nothing to send again"

    Submission.sole.update!(status: "received")
    viewer = users(:author)
    viewer.roles = [ Nibble::Role.create!(handle: "help_viewer", title: "Help viewer", abilities: %w[forms.help.view]) ]
    sign_in_as viewer
    assert_not can_resend.call
  end

  test "staff mail links to the submission in the Control Plane and the visitor's does not" do
    perform_enqueued_jobs { submit }
    id = Submission.sole.id

    assert_includes mail_to("desk@example.test").text_part.body.to_s, "https://example.com/cp/forms/help/submissions/#{id}"
    assert_includes mail_to("desk@example.test").html_part.body.to_s, "https://example.com/cp/forms/help/submissions/#{id}"
    assert_not_includes mail_to("ada@example.test").text_part.body.to_s, "/cp/"
    assert_not_includes mail_to("ada@example.test").html_part.body.to_s, "/cp/"
  end

  test "nibble:check rejects references that can't resolve, and secrets in email" do
    item = Nibble::Schema::Item.new(kind: :forms, handle: "x", parent: nil, path: "x.yml", layer: :site, data: {
      "title" => "X", "fields" => [ { "handle" => "email", "field" => { "type" => "text" } } ],
      "success" => { "message" => "{global.nope.thanks}" },
      "notify" => [ { "to" => [ "{field.missing}", "{global.contact.nothing}", "Ada <{field.email}>" ], "subject" => "{secret.crm_token}",
                      "if" => { "ghost" => "x" } } ]
    })
    problems = Nibble::Forms.problems(Nibble::Forms::Form.new(item:), schema: Nibble.schema)

    assert_equal 6, problems.size, problems.join("\n")
    assert_empty Nibble::Forms.problems(Nibble::Forms.find("help"), schema: Nibble.schema)
  end
end
