require "test_helper"

class FormStepsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  Submission = Nibble::Records::FormSubmission
  STEP_ONE = { email: "ada@example.test", kind: "person" }.freeze

  setup do
    @store = ActiveSupport::Cache::MemoryStore.new
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { @store }
    @nibble_themes.join("records/schema/forms/apply.yml").write({
      "title" => "Apply", "steps" => true, "notify" => [ { "to" => "sales@example.test" } ], "cp_notify" => true,
      "sections" => [
        { "display" => "You", "fields" => [
          { "handle" => "email", "field" => { "type" => "text", "input_type" => "email", "required" => true } },
          { "handle" => "kind", "field" => { "type" => "radio", "required" => true, "options" => { "business" => "Business", "person" => "Person" } } }
        ] },
        { "display" => "About it", "fields" => [
          { "handle" => "company", "field" => { "type" => "text", "required" => true, "if" => { "kind" => "business" } } },
          { "handle" => "size", "field" => { "type" => "integer", "required" => true } }
        ] }
      ]
    }.to_yaml)
    Nibble.reset_schema!
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def check(index, values) = post("/forms/apply/steps/#{index}", params: values, as: :json)

  test "a step check judges only that step's fields, so a visitor isn't told about questions they haven't reached" do
    check 0, {}

    assert_response :unprocessable_entity
    assert_equal %w[email kind], response.parsed_body["errors"].keys.sort
  end

  test "a step check applies conditions to what was posted, as the final submit will" do
    check 1, STEP_ONE
    assert_equal %w[size], response.parsed_body["errors"].keys

    check 1, STEP_ONE.merge(kind: "business")
    assert_equal %w[company size], response.parsed_body["errors"].keys.sort
  end

  test "a passing step check stores, announces and sends nothing" do
    assert_no_enqueued_jobs do
      check 0, STEP_ONE
    end

    assert_response :ok
    assert_equal({ "ok" => true }, response.parsed_body)
    assert_equal 0, Submission.count
    assert_equal 0, Nibble::Records::OutboxEvent.count
    assert_empty ActionMailer::Base.deliveries
  end

  test "the final submit still judges every step, whatever the step checks said" do
    check 0, STEP_ONE
    assert_response :ok

    post "/forms/apply", params: STEP_ONE, as: :json

    assert_response :unprocessable_entity
    assert_equal %w[size], response.parsed_body["errors"].keys
    assert_equal 0, Submission.count
  end

  test "step checks don't use up a visitor's submissions, and have a generous cap of their own" do
    6.times { check 0, STEP_ONE }
    post "/forms/apply", params: STEP_ONE.merge(size: 3), as: :json
    assert_response :created

    (5 * Nibble::Forms::Step::CHECKS_PER_REQUEST).times { check 0, STEP_ONE }
    assert_response :too_many_requests
  end

  test "only a form with steps has step checks, and only for a step it has" do
    check 2, STEP_ONE
    assert_response :not_found

    post "/forms/visit/steps/0", params: {}, as: :json
    assert_response :not_found
  end

  test "a step check on a closed form says so before the visitor fills in the rest" do
    path = @nibble_themes.join("records/schema/forms/apply.yml")
    path.write(YAML.safe_load(path.read).merge("limits" => { "closes_at" => "2020-01-01T00:00" }).to_yaml)
    Nibble.reset_schema!

    check 0, STEP_ONE

    assert_equal [ "This form isn't taking submissions right now." ], response.parsed_body["errors"]["base"]
  end

  test "the definition says a form has steps, and a flat or plain sectioned form says it hasn't" do
    assert Nibble::Forms::Definition.call(Nibble::Forms.find("apply"))["steps"]
    assert_not Nibble::Forms::Definition.call(Nibble::Forms.find("visit"))["steps"]
    assert_not Nibble::Forms::Definition.call(Nibble::Forms.find("contact"))["steps"]
  end
end
