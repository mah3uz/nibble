require "test_helper"

class FormResumeTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  Partial = Nibble::Records::FormPartial
  Submission = Nibble::Records::FormSubmission
  SAVED = { email: "ada@example.test", phone: "0412 345 678", kind: "person", source: "news", _nibble_page: "/apply" }.freeze

  setup do
    @store = ActiveSupport::Cache::MemoryStore.new
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { @store }
    ActionMailer::Base.deliveries.clear
    @nibble_themes.join("records/schema/forms/apply.yml").write({
      "title" => "Apply", "steps" => true, "resume" => true, "resume_email" => "email", "resume_days" => 3,
      "notify" => [ { "to" => "sales@example.test" } ], "cp_notify" => true,
      "sections" => [
        { "display" => "You", "fields" => [
          { "handle" => "email", "field" => { "type" => "text", "input_type" => "email", "required" => true } },
          { "handle" => "phone", "field" => { "type" => "text", "encrypt" => true } },
          { "handle" => "kind", "field" => { "type" => "radio", "required" => true, "options" => { "business" => "Business", "person" => "Person" } } },
          { "handle" => "source", "field" => { "type" => "text", "hidden" => true, "prefill" => { "query" => "utm_source" } } }
        ] },
        { "display" => "Files", "fields" => [
          { "handle" => "brief", "field" => { "type" => "files", "extensions" => [ "pdf" ] } },
          { "handle" => "size", "field" => { "type" => "integer", "required" => true } }
        ] }
      ]
    }.to_yaml)
    Nibble.reset_schema!
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def form = Nibble::Forms.find("apply")
  def save(values = SAVED, **options) = post("/forms/apply/resume", params: values, **options)
  def token = ActionMailer::Base.deliveries.last.text_part.body.to_s[/resume=([\w-]+)/, 1]
  def restore(token) = Nibble::Dependencies.track { Nibble::Forms::Definition.call(form, params: { "resume" => token }) }
  def stored_text = Partial.connection.select_all("SELECT * FROM form_partials").rows.flatten.join(" ")

  test "saving keeps what was entered for resume_days, encrypted where the form says, and emails the visitor a link to it" do
    pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4"), "application/pdf", original_filename: "brief.pdf")
    save SAVED.merge(brief: pdf)

    assert_response :ok
    assert_equal "We've emailed you a link to finish this form. It works for 3 days.", response.parsed_body["message"]
    partial = Partial.sole
    assert_equal({ "email" => "ada@example.test", "phone" => "0412 345 678", "kind" => "person", "source" => "news" }, partial.data)
    assert_in_delta 3.days.from_now, partial.expires_at, 5
    assert_equal 0, ActiveStorage::Blob.count, "a saved form never keeps files; the visitor attaches them again"

    mail = ActionMailer::Base.deliveries.sole
    assert_equal [ "ada@example.test" ], mail.to
    assert_includes mail.text_part.body.to_s, "https://example.com/apply?resume=#{token}"
    assert_not_includes stored_text, "0412 345 678"
    assert_not_includes stored_text, token, "only the token's digest is stored, so the database alone can't open a saved form"
  end

  test "a saved form is never a submission: nothing is stored as one, announced, emailed to staff or delivered" do
    assert_no_enqueued_jobs { save }

    assert_equal 0, Submission.count
    assert_equal 0, Nibble::Records::OutboxEvent.count
    assert_equal [ [ "ada@example.test" ] ], ActionMailer::Base.deliveries.map(&:to)
  end

  test "the link restores what was saved, hidden fields included, and the page isn't cached for anyone else" do
    save
    (definition, tags) = restore(token)

    assert_equal({ "handle" => "apply", "status" => "resumed", "values" => Partial.sole.data }, definition["result"])
    assert_equal({ "email" => "email", "days" => 3, "token" => token }, definition["resume"])
    assert_equal "news", definition["fields"].find { |field| field["handle"] == "source" }["value"]
    assert_equal "/forms/apply?utm_source=news", definition["action"]
    assert_includes tags, Nibble::Dependencies::UNCACHEABLE
  end

  test "an expired or wrong link restores nothing" do
    save
    saved = token

    [ "x" * 43, saved.reverse, "" ].each do |wrong|
      assert_not_equal "resumed", restore(wrong).first.dig("result", "status")
    end
    travel 4.days do
      (definition, _tags) = restore(saved)
      assert_equal "expired", definition["result"]["status"]
      assert_nil definition["result"]["values"]
      assert_nil definition["resume"]["token"]
    end
  end

  test "sending the form deletes what was saved, and a refused send keeps it" do
    save
    saved = token

    post "/forms/apply", params: SAVED.merge(_nibble_resume: saved), as: :json
    assert_response :unprocessable_entity
    assert Partial.exists?

    post "/forms/apply", params: SAVED.merge(size: 2, _nibble_resume: saved), as: :json
    assert_response :created
    assert_not Partial.exists?
  end

  test "saving again replaces the earlier save, so one visitor holds one link" do
    save
    first = token
    save SAVED.merge(_nibble_resume: first, kind: "business")

    assert_equal "business", Partial.sole.data["kind"]
    assert_nil Nibble::Records::FormPartial.find_live("apply", first)
  end

  test "saving needs the visitor's email address, and keeps nothing without it" do
    save SAVED.merge(email: "not an address")

    assert_response :unprocessable_entity
    assert_equal [ "email" ], response.parsed_body["errors"].keys
    assert_equal 0, Partial.count
    assert_empty ActionMailer::Base.deliveries
  end

  test "a bot caught by the honeypot is told it saved, and nothing is kept or emailed" do
    save SAVED.merge(_nibble_hp: "spam")

    assert_response :ok
    assert_equal 0, Partial.count
    assert_empty ActionMailer::Base.deliveries
  end

  test "saving is rate limited like submitting, so the form can't be used to send email in bulk" do
    6.times { save }

    assert_response :too_many_requests
    assert_equal 5, Partial.count
  end

  test "a link that couldn't be emailed isn't kept" do
    Nibble::FormsMailer.define_singleton_method(:resume) { |*| raise Net::SMTPFatalError, "no" }
    begin
      save
    ensure
      Nibble::FormsMailer.singleton_class.remove_method(:resume)
    end

    assert_response :unprocessable_entity
    assert_equal [ "We couldn't send the email. Please try again." ], response.parsed_body["errors"]["base"]
    assert_equal 0, Partial.count
  end

  test "the daily purge deletes saved forms once they expire" do
    save
    live = Partial.sole
    expired = Partial.create!(form: "apply", token_digest: "d", expires_at: 1.minute.ago)

    Nibble::Jobs::PurgeSubmissions.perform_now

    assert_equal [ live.id ], Partial.ids
    assert_not Partial.exists?(expired.id)
  end

  test "erasing a person deletes their saved forms too, even where the address is only in an encrypted field" do
    save
    other = SAVED.merge(email: "grace@example.test")
    save other

    sign_in_as users(:admin)
    get "/cp/personal-data", params: { email: "ada@example.test" }
    assert_equal 1, JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]["saved"]

    delete "/cp/personal-data", params: { email: "ada@example.test" }
    assert_equal [ "grace@example.test" ], Partial.all.map { |partial| partial.data["email"] }
    assert_equal 1, Nibble::Records::AuditEntry.where(action: "form.person_erased").sole.changeset["saved"]
  end

  test "a form without resume has no saving, and the definition carries no resume" do
    post "/forms/contact/resume", params: SAVED
    assert_response :not_found
    assert_nil Nibble::Forms::Definition.call(Nibble::Forms.find("contact"))["resume"]
  end
end
