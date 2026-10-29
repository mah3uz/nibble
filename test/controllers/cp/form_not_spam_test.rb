require "test_helper"
require "webmock"

class Nibble::Cp::FormNotSpamTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper
  include WebMock::API

  Submission = Nibble::Records::FormSubmission
  CRM = "https://crm.example.test/leads".freeze
  HOOK = "https://hooks.example.test/in".freeze
  VALUES = { email: "ada@example.test", message: "<script>alert(1)</script>" }.freeze
  FOLLOW_UPS = [ Nibble::Jobs::NotifySubmission, Nibble::Jobs::HandleSubmission, Nibble::Jobs::DeliverSubmission ].freeze

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: true)
    @resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { ActiveSupport::Cache::MemoryStore.new }
    @handled = handled = []
    Nibble::Forms.register_handler("test.callback", ->(form:, data:, submission:) { handled << submission.id })
    @nibble_themes.join("records/schema/forms/callback.yml").write({
      "title" => "Callback", "handler" => "test.callback", "notify" => [ { "to" => "sales@example.test" } ],
      "api" => [ { "url" => CRM, "mode" => "sync" }, { "url" => HOOK, "mode" => "async" } ],
      "fields" => [ { "handle" => "email", "field" => { "type" => "text", "input_type" => "email", "required" => true } },
                    { "handle" => "message", "field" => { "type" => "textarea" } } ]
    }.deep_stringify_keys.to_yaml)
    Nibble.reset_schema!
    stub_request(:post, CRM).to_return(status: 201)
    stub_request(:post, HOOK).to_return(status: 200)
    sign_in_as users(:editor)
  end

  teardown do
    Nibble::Forms.handlers.delete("test.callback")
    Nibble::Outbound::Guard.resolver = @resolver
    Nibble::Forms::Submit.rate_limit_store = @rate_limit_store
    WebMock.reset!
    WebMock.disable!
  end

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)
  def caught(values = VALUES) = post("/forms/callback", params: values.merge(_nibble_hp: "autofilled"), as: :json)
  def submission = Submission.sole
  def path = "/cp/forms/callback/submissions/#{submission.id}"

  test "a wrongly caught enquiry can be read as plain text, and marked as not spam by someone who can edit the form" do
    caught
    assert_no_enqueued_jobs only: FOLLOW_UPS
    assert_not_requested :post, CRM

    get path
    props = page["props"]
    assert_equal [ "spam", true, true ], [ props["submission"]["status"], props["submission"]["values_kept"], props["can_mark_not_spam"] ]
    assert_equal "<script>alert(1)</script>", props["values"]["message"], "the value reaches the page as text, not markup"
    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_equal 30, props["spam_days"]
  end

  test "Not spam stores and delivers it as a fresh real submission, exactly once however often it is asked" do
    caught

    perform_enqueued_jobs do
      post "#{path}/not_spam"
      assert_redirected_to path
      post "#{path}/not_spam"
    end

    assert_equal [ "delivered", VALUES.stringify_keys ], [ submission.status, submission.data ]
    assert_requested :post, CRM, times: 1
    assert_requested :post, HOOK, times: 1
    assert_equal [ [ "sales@example.test" ] ], ActionMailer::Base.deliveries.map(&:to)
    assert_equal [ submission.id ], @handled
    assert_equal 1, Nibble::Records::OutboxEvent.where(name: "form.submitted").count, "webhooks hear about it once"
    audit = Nibble::Records::AuditEntry.where(action: "form.not_spam").sole
    assert_equal [ users(:editor).id, "form_submission", submission.id ], audit.values_at(:actor_id, :subject_type, :subject_id)
  end

  test "two requests racing on the same spam row deliver it once" do
    caught
    form = Nibble::Forms.find("callback")
    first, second = Submission.find(submission.id), Submission.find(submission.id)

    perform_enqueued_jobs do
      assert_equal :ok, Nibble::Forms::Submit.not_spam(form, first, user: users(:editor)).status
      assert_equal :not_spam, Nibble::Forms::Submit.not_spam(form, second, user: users(:admin)).status
    end
    assert_requested :post, CRM, times: 1
    assert_requested :post, HOOK, times: 1
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal 1, Nibble::Records::AuditEntry.where(action: "form.not_spam").count
  end

  test "someone who can only view the form's submissions can't mark one as not spam" do
    caught
    user = users(:author)
    user.roles = [ Nibble::Role.create!(handle: "callback_viewer", title: "Callback viewer", abilities: %w[forms.callback.view]) ]
    sign_in_as user

    get path
    assert_not page["props"]["can_mark_not_spam"]
    post "#{path}/not_spam"
    assert_response :forbidden
    assert_equal "spam", submission.reload.status
    assert_no_enqueued_jobs only: FOLLOW_UPS
  end

  test "spam whose values weren't kept can't be marked as not spam, so nothing empty is sent on" do
    Submission.create!(form: "callback", status: "spam")

    get path
    assert_equal false, page["props"]["submission"]["values_kept"]
    post "#{path}/not_spam"
    assert_equal "Its values are no longer kept, so it can't be marked as not spam.", flash[:alert]
    assert_equal "spam", submission.reload.status
    assert_no_enqueued_jobs only: FOLLOW_UPS
    assert_not_requested :post, CRM
  end

  test "kept values that don't pass the form's checks stay spam rather than being sent on" do
    caught VALUES.merge(email: "not-an-email")

    post "#{path}/not_spam"
    assert_match "can't be marked as not spam", flash[:alert]
    assert_equal "spam", submission.reload.status
    assert_not_requested :post, CRM
  end
end
