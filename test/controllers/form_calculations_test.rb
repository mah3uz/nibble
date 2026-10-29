require "test_helper"

class FormCalculationsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  Submission = Nibble::Records::FormSubmission
  QUOTE = { title: "Quote", success: { message: "Thanks." }, fields: [
    { handle: "quantity", field: { type: "integer" } },
    { handle: "size", field: { type: "select", options: { "10" => "Small", "25" => "Large" } } },
    { handle: "express", field: { type: "toggle" } },
    { handle: "delivery", field: { type: "radio", options: { "0" => "Collect", "15" => "Deliver" } } },
    { handle: "postcode_fee", field: { type: "integer", if: { delivery: "15" } } },
    { handle: "subtotal", field: { type: "calculation", formula: "{quantity} * {size} + {express} * 20" } },
    { handle: "total", field: { type: "calculation", formula: "{subtotal} + {delivery} + {postcode_fee}", decimals: 2, prepend: "$" } }
  ] }.freeze

  setup do
    @store = ActiveSupport::Cache::MemoryStore.new
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { @store }
    path = @nibble_themes.join("records", "schema", "forms", "quote.yml")
    path.write(QUOTE.deep_stringify_keys.to_yaml)
    Nibble.reset_schema!
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def submit(values) = post("/forms/quote", params: values, as: :json)

  test "the stored total is the server's own calculation, whatever total the browser posted" do
    submit quantity: "3", size: "25", express: "true", delivery: "0", subtotal: 1, total: 999_999

    assert_response :created
    data = Submission.sole.data
    assert_equal [ 95, 95 ], data.values_at("subtotal", "total")
  end

  test "an input hidden by its condition counts as 0, even when the browser posts it" do
    submit quantity: "1", size: "10", delivery: "0", postcode_fee: "30"
    submit quantity: "1", size: "10", delivery: "15", postcode_fee: "30"

    assert_equal [ 10, 55 ], Submission.order(:id).map { |submission| submission.data["total"] }
  end

  test "a submission caught as spam keeps no posted total, and one marked not spam is recalculated" do
    submit quantity: "2", size: "10", total: 5, _nibble_hp: "bot"

    spam = Submission.sole
    assert_equal "spam", spam.status
    assert_not spam.data.key?("total")

    form = Nibble::Forms.find("quote")
    assert Nibble::Forms::Submit.not_spam(form, spam, user: users(:admin)).ok?
    assert_equal 20, spam.reload.data["total"]
  end

  test "emails, exports and the CP show the total with its decimals and prepend" do
    total = Nibble::Forms.find("quote").fields.get("total")

    assert_equal "$1,250.00", Nibble::Forms.display_value(total, 1250)
    assert_nil Nibble::Forms.display_value(total, nil)
  end

  test "the page's form definition carries the formula for the theme to run, and no posted value is wanted back" do
    fields = Nibble::Forms::Definition.call(Nibble::Forms.find("quote"))["fields"]
    total = fields.find { |field| field["handle"] == "total" }

    assert_equal({ "type" => "calculation", "formula" => "{subtotal} + {delivery} + {postcode_fee}", "decimals" => 2, "prepend" => "$" },
      total.slice("type", "formula", "decimals", "prepend"))
    assert_not total.key?("default")
  end
end
