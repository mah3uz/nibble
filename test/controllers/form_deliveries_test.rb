require "test_helper"
require "webmock"

class FormDeliveriesTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper
  include WebMock::API

  CRM = "https://crm.example.test/v1/leads".freeze
  HOOK = "https://hooks.example.test/in".freeze

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!
    ENV["NIBBLE_SECRET_CRM_TOKEN"] = "crm-secret"
    @resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { ActiveSupport::Cache::MemoryStore.new }
  end

  teardown do
    Nibble::Outbound::Guard.resolver = @resolver
    Nibble::Forms::Submit.rate_limit_store = @rate_limit_store
    ENV.delete("NIBBLE_SECRET_CRM_TOKEN")
    WebMock.reset!
    WebMock.disable!
  end

  def submit(handle, values) = post("/forms/#{handle}", params: values, as: :json)
  def submission = Nibble::Records::FormSubmission.sole

  test "a sync delivery sends the mapped body with the connection's headers, and async ones follow as jobs" do
    stub_request(:post, CRM).to_return(status: 201)
    stub_request(:post, HOOK).to_return(status: 200)

    submit :lead, { email: "ada@example.test" }
    assert_response :created
    assert_requested(:post, CRM, body: { email_address: "ada@example.test", source: "web" }.to_json,
      headers: { "Authorization" => "Bearer crm-secret" })
    assert_equal "delivered", submission.delivery("api.0")["status"]
    assert_equal "received", submission.status, "the async delivery hasn't run yet"

    perform_enqueued_jobs(only: Nibble::Jobs::DeliverSubmission)
    assert_requested(:post, HOOK, body: { email: "ada@example.test" }.to_json)
    assert_equal "delivered", submission.reload.status
    assert_equal [ "[redacted]" ], Nibble::Records::OutboundRequest.where(owner_id: submission.id).map { |log| log.request_headers["Authorization"] }.compact
  end

  test "a remote rejection comes back to the visitor on the form's own fields" do
    stub_request(:post, CRM).to_return(status: 422, body: { errors: { email_address: [ "is already subscribed" ], plan: [ "is full" ] } }.to_json)

    submit :lead, { email: "ada@example.test" }
    assert_response :unprocessable_entity
    assert_equal({ "email" => [ "is already subscribed" ], "base" => [ "is full" ] }, response.parsed_body["errors"])
    assert_equal "rejected", submission.status
    assert_no_enqueued_jobs(only: Nibble::Jobs::DeliverSubmission) { Nibble::Forms::Deliver.call(Nibble::Forms.find("lead"), 0, submission.data, submission:) }
  end

  test "when the remote system is down the visitor still gets through and the delivery retries later" do
    stub_request(:post, CRM).to_return(status: 503)

    submit :lead, { email: "ada@example.test" }
    assert_response :created
    assert_equal [ "failed", 1, "HTTP 503" ], submission.delivery("api.0").values_at("status", "attempts", "error")
    assert_enqueued_with(job: Nibble::Jobs::DeliverSubmission, args: [ "lead", 0, { submission_id: submission.id, data: nil, attempt: 2 } ])
  end

  test "background retries back off and stop at the connection's attempt limit" do
    stub_request(:post, CRM).to_return(status: 500)
    stub_request(:post, HOOK).to_return(status: 200)
    submit :lead, { email: "ada@example.test" }
    clear_enqueued_jobs

    Nibble::Jobs::DeliverSubmission.perform_now("lead", 0, submission_id: submission.id, attempt: 2)
    assert_enqueued_with(job: Nibble::Jobs::DeliverSubmission, args: [ "lead", 0, { submission_id: submission.id, data: nil, attempt: 3 } ],
      at: 20.seconds.from_now.round)
    clear_enqueued_jobs
    Nibble::Jobs::DeliverSubmission.perform_now("lead", 0, submission_id: submission.id, attempt: 3)
    assert_no_enqueued_jobs
    assert_equal [ "failed", 3 ], submission.reload.delivery("api.0").values_at("status", "attempts")
  end

  test "the CP can retry a failed delivery, which runs it again from pending" do
    stub_request(:post, CRM).to_return(status: 503)
    submit :lead, { email: "ada@example.test" }
    clear_enqueued_jobs

    Nibble::Forms::Deliver.retry!(submission, "api.0")
    assert_equal "pending", submission.reload.delivery("api.0")["status"]
    stub_request(:post, CRM).to_return(status: 201)
    perform_enqueued_jobs(only: Nibble::Jobs::DeliverSubmission)
    assert_equal "delivered", submission.reload.delivery("api.0")["status"]
  end

  test "a form that stores nothing still delivers, carrying its data in the job" do
    stub_request(:post, "https://hooks.example.test/quick").to_return(status: 200)

    submit :quick, { email: "ada@example.test" }
    assert_response :created
    assert_empty Nibble::Records::FormSubmission.all
    perform_enqueued_jobs(only: Nibble::Jobs::DeliverSubmission)
    assert_requested(:post, "https://hooks.example.test/quick", body: { email: "ada@example.test" }.to_json)
  end
end
