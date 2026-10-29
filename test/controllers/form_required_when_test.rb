require "test_helper"

class FormRequiredWhenTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  Submission = Nibble::Records::FormSubmission
  CALLBACK = { title: "Callback", success: { message: "Thanks." }, fields: [
    { handle: "by", field: { type: "radio", options: { "phone" => "Phone", "email" => "Email" } } },
    { handle: "phone", field: { type: "text", required: { if: { by: "phone" } } } },
    { handle: "note", field: { type: "text", if: { by: "phone" } } }
  ] }.freeze

  setup do
    @store = ActiveSupport::Cache::MemoryStore.new
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { @store }
    @nibble_themes.join("records", "schema", "forms", "callback.yml").write(CALLBACK.deep_stringify_keys.to_yaml)
    Nibble.reset_schema!
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def submit(values) = post("/forms/callback", params: values, as: :json)

  test "a field required only for phone callers may be blank otherwise, and is refused blank for them" do
    submit by: "email"
    assert_response :created

    submit by: "phone"
    assert_response :unprocessable_entity
    assert_equal 1, Submission.count

    submit by: "phone", phone: "0400 000 000"
    assert_response :created
  end

  test "the definition says required as the condition a theme can evaluate" do
    fields = Nibble::Forms::Definition.call(Nibble::Forms.find("callback"))["fields"].index_by { |field| field["handle"] }

    assert_equal false, fields["by"]["required"]
    assert_equal({ "show" => true, "match" => "all", "rules" => [ { "field" => "by", "operator" => "equals", "value" => "phone" } ] }, fields["phone"]["required"])
  end

  test "a value posted for a field its condition hides is stored as sent" do
    submit by: "email", note: "kept anyway"

    assert_response :created
    assert_equal "kept anyway", Submission.sole.data["note"]
  end
end
