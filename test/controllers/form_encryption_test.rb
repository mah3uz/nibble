require "test_helper"
require "webmock"

class FormEncryptionTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper
  include WebMock::API

  Submission = Nibble::Records::FormSubmission
  CRM = "https://crm.example.test/leads".freeze
  VALUES = { email: "ada@example.test", phone: "0412 345 678", message: "Call me after five" }.freeze

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: true)
    @resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { ActiveSupport::Cache::MemoryStore.new }
    @handled = handled = []
    Nibble::Forms.register_handler("test.private", ->(form:, data:, submission:) { handled << data })
    @nibble_themes.join("records/schema/forms/private.yml").write({
      "title" => "Private", "handler" => "test.private", "notify" => [ { "to" => "sales@example.test" } ],
      "api" => [ { "url" => CRM, "mode" => "sync" } ],
      "fields" => [ { "handle" => "email", "field" => { "type" => "text", "input_type" => "email", "required" => true, "encrypt" => true } },
                    { "handle" => "phone", "field" => { "type" => "text", "encrypt" => true } },
                    { "handle" => "message", "field" => { "type" => "textarea" } } ]
    }.to_yaml)
    Nibble.reset_schema!
    stub_request(:post, CRM).to_return(status: 201, body: { "echo" => "0412 345 678" }.to_json)
  end

  teardown do
    Nibble::Forms.handlers.delete("test.private")
    Nibble::Outbound::Guard.resolver = @resolver
    Nibble::Forms::Submit.rate_limit_store = @rate_limit_store
    WebMock.reset!
    WebMock.disable!
  end

  def page = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)

  def stored_text(table, id) = Submission.connection.select_one("SELECT * FROM #{table} WHERE id = #{id.to_i}").values.join(" ")

  def assert_no_secrets(text)
    [ "ada@example.test", "0412 345 678", "0412+345+678" ].each { |secret| assert_not_includes text, secret }
  end

  test "the database holds an encrypted field only as ciphertext, while staff, exports, emails, deliveries and handlers see the value" do
    perform_enqueued_jobs { post "/forms/private", params: VALUES, as: :json }

    assert_response :created
    submission = Submission.sole
    assert_no_secrets stored_text("form_submissions", submission.id)
    assert_includes stored_text("form_submissions", submission.id), "Call me after five"
    assert_equal VALUES.stringify_keys, submission.data.slice(*VALUES.keys.map(&:to_s))

    assert_requested(:post, CRM) { |request| JSON.parse(request.body)["phone"] == "0412 345 678" }
    Nibble::Records::OutboundRequest.find_each { |logged| assert_no_secrets stored_text("outbound_requests", logged.id) }
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.to_s, "0412 345 678"
    assert_equal "0412 345 678", @handled.sole["phone"]

    sign_in_as users(:editor)
    get "/cp/forms/private/submissions/#{submission.id}"
    assert_equal [ "ada@example.test", "0412 345 678" ], page["props"]["values"].values_at("email", "phone")
    get "/cp/forms/private.csv"
    assert_equal [ "ada@example.test", "0412 345 678" ], CSV.parse(response.body, headers: true).first.to_h.values_at("Email", "Phone")
  end

  test "finding a person decrypts as it scans, so an address kept only in an encrypted field is still found and exported" do
    post "/forms/private", params: VALUES.merge(email: "Jane@Example.test"), as: :json
    post "/forms/private", params: VALUES.merge(email: "janet@example.test"), as: :json
    jane = Submission.order(:id).first

    sign_in_as users(:admin)
    get "/cp/personal-data/export.json", params: { email: "jane@example.test" }
    exported = JSON.parse(response.body)
    assert_equal [ jane.id ], exported.map { |row| row["id"] }
    assert_equal "0412 345 678", exported.sole["values"]["phone"]
  end

  test "a ciphertext copied onto another submission can't be read there, because each is bound to its own submission and field" do
    post "/forms/private", params: VALUES, as: :json
    post "/forms/private", params: VALUES.merge(email: "grace@example.test", phone: "0499 999 999"), as: :json
    first, second = Submission.order(:id).to_a

    second.update_column(:encrypted_data, first.encrypted_data)
    assert_nil Submission.find(second.id).data["email"]
    second.update_column(:encrypted_data, { "email" => first.encrypted_data["phone"] })
    assert_nil Submission.find(second.id).data["email"]
  end

  test "caught spam is encrypted too, and stays encrypted once marked as not spam" do
    post "/forms/private", params: VALUES.merge(_nibble_hp: "autofilled"), as: :json
    submission = Submission.sole
    assert_equal "spam", submission.status
    assert_no_secrets stored_text("form_submissions", submission.id)

    outcome = Nibble::Forms::Submit.not_spam(Nibble::Forms.find("private"), submission, user: users(:editor))
    assert outcome.ok?
    assert_equal "delivered", submission.reload.status
    assert_no_secrets stored_text("form_submissions", submission.id)
    assert_equal "0412 345 678", submission.data["phone"]
  end
end
