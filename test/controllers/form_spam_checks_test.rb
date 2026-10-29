require "test_helper"

class FormSpamChecksTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  Submission = Nibble::Records::FormSubmission

  setup do
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { ActiveSupport::Cache::MemoryStore.new }
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def form_file(handle, spam)
    @nibble_themes.join("records/schema/forms/#{handle}.yml").write({
      "title" => handle.humanize, "spam" => spam,
      "fields" => [ { "handle" => "email", "field" => { "type" => "text", "input_type" => "email", "required" => true } },
                    { "handle" => "message", "field" => { "type" => "textarea" } } ]
    }.to_yaml)
    Nibble.reset_schema!
  end

  def submit(handle, values) = post("/forms/#{handle}", params: values, as: :json)
  def timestamp(handle) = Nibble::Forms::Definition.call(Nibble::Forms.find(handle))["timestamp"]

  test "a submission sent sooner after the form was shown than min_seconds is kept as spam, and a patient one is received" do
    form_file("paced", { "min_seconds" => 3 })
    token = timestamp("paced")

    travel(2.seconds) { submit :paced, { email: "bot@example.test", _nibble_t: token } }
    assert_response :created, "a bot is told it was sent"
    travel(4.seconds) { submit :paced, { email: "ada@example.test", _nibble_t: token } }

    assert_equal({ "bot@example.test" => "spam", "ada@example.test" => "received" }, Submission.all.to_h { |row| [ row.data["email"], row.status ] })
    assert_not Submission.where(status: "received").sole.data.key?("_nibble_t")
  end

  test "a missing, altered or another form's timestamp is spam, since a bot could otherwise leave it out or make one up" do
    form_file("paced", { "min_seconds" => 3 })
    form_file("other", { "min_seconds" => 3 })
    tokens = [ nil, "#{timestamp('paced')}x", timestamp("other"), { "at" => 1 } ]

    travel(10.seconds) { tokens.each { |token| submit :paced, { email: "bot@example.test", _nibble_t: token } } }
    assert_equal [ "spam" ] * 4, Submission.where(form: "paced").pluck(:status)
  end

  test "a form without min_seconds carries no timestamp and needs none" do
    form_file("plain", {})

    assert_nil timestamp("plain")
    submit :plain, { email: "ada@example.test" }
    assert_equal "received", Submission.sole.status
  end

  test "text with more links than max_links is spam, counted across the text fields" do
    form_file("linked", { "max_links" => 2 })

    submit :linked, { email: "ada@example.test", message: "See https://example.test/a and www.example.test" }
    submit :linked, { email: "bot@example.test", message: "https://spam.test/1 http://spam.test/2 www.spam.test/3" }

    assert_equal({ "ada@example.test" => "received", "bot@example.test" => "spam" }, Submission.all.to_h { |row| [ row.data["email"], row.status ] })
  end

  test "Not spam rescues a submission caught by either check" do
    form_file("linked", { "max_links" => 0, "min_seconds" => 60 })
    submit :linked, { email: "ada@example.test", message: "My site is https://ada.example.test", _nibble_t: timestamp("linked") }

    outcome = Nibble::Forms::Submit.not_spam(Nibble::Forms.find("linked"), Submission.sole, user: users(:editor))
    assert outcome.ok?
    assert_equal "received", Submission.sole.status
  end
end
