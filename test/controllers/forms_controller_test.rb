require "test_helper"
require "webmock"

class FormsControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include WebMock::API

  Submission = Nibble::Records::FormSubmission
  VALID = { name: "Ada", email: "ada@example.test", topic: "sales", message: "Hello there" }.freeze
  TURNSTILE = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!
    @store = ActiveSupport::Cache::MemoryStore.new
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { @store }
    @resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
  end

  teardown do
    Nibble::Forms::Submit.rate_limit_store = @rate_limit_store
    Nibble::Outbound::Guard.resolver = @resolver
    WebMock.reset!
    WebMock.disable!
  end

  def submit(handle, values, **options) = post("/forms/#{handle}", params: values, as: :json, **options)

  def captcha(provider:, secret: "secret", **extra)
    record = Nibble::Records::GlobalSet.find_or_initialize_by(handle: "integrations", locale: "en")
    values = { "captcha_provider" => provider, "captcha_site_key" => "site", "captcha_secret_key" => { "plain" => secret } }
    lifecycle(record, :save, values.merge(extra.stringify_keys))
  end

  test "a valid submission is stored with only the form's fields, and announced once" do
    submit :contact, VALID.merge(admin: true, status: "delivered")

    assert_response :created
    assert_equal "Thanks, we'll be in touch.", response.parsed_body["message"]
    submission = Submission.sole
    assert_equal [ "contact", "received", VALID.stringify_keys ], [ submission.form, submission.status, submission.data ]
    assert_equal [ "form.submitted" ], Nibble::Records::OutboxEvent.where(name: "form.submitted").pluck(:name)
    assert_not_nil submission.ip_hash
  end

  test "invalid input comes back keyed by field and nothing is stored" do
    submit :contact, VALID.merge(email: "not-an-email", message: "x" * 501, topic: "billing").except(:name)

    assert_response :unprocessable_entity
    assert_equal %w[email message name topic], response.parsed_body["errors"].keys.sort
    assert_empty Submission.all
  end

  test "a filled honeypot looks like success to the bot but is kept only as spam" do
    submit :contact, VALID.merge(_nibble_hp: "http://spam.test")

    assert_response :created
    assert_equal [ "spam", {} ], Submission.sole.values_at(:status, :data)
    assert_empty Nibble::Records::OutboxEvent.where(name: "form.submitted")
  end

  test "a burst of submissions from one address is cut off at the form's rate limit" do
    5.times { submit :contact, VALID }
    submit :contact, VALID

    assert_response :too_many_requests
    assert_equal 5, Submission.count
  end

  test "a form that doesn't store keeps nothing, and skips CAPTCHA until one is configured" do
    submit :signup, { email: "ada@example.test" }

    assert_response :created
    assert_equal "/thanks", response.parsed_body["redirect"]
    assert_empty Submission.all
  end

  test "Turnstile tokens are verified server-side, and a failed or missing check blocks the submission" do
    captcha(provider: "turnstile")
    stub_request(:post, TURNSTILE).with(body: hash_including("response" => "good")).to_return(body: { success: true }.to_json)
    stub_request(:post, TURNSTILE).with(body: hash_including("response" => "bad")).to_return(body: { success: false }.to_json)

    submit :signup, { email: "ada@example.test" }
    assert_response :unprocessable_entity
    submit :signup, { email: "ada@example.test", _captcha: "bad" }
    assert_response :unprocessable_entity
    submit :signup, { email: "ada@example.test", "cf-turnstile-response" => "good" }
    assert_response :created
    assert_requested(:post, TURNSTILE, times: 2) { |request| request.body.include?("secret=secret") }
    assert_not_includes Nibble::Records::OutboundRequest.pluck(:request_body).join, "secret=secret", "the secret is redacted in the log"
  end

  test "reCAPTCHA v3 scores below the site's minimum are treated as bots, 0.5 unless the settings say otherwise" do
    assert captcha(provider: "recaptcha").ok?
    stub_request(:post, "https://www.google.com/recaptcha/api/siteverify").to_return(body: { success: true, score: 0.3 }.to_json)

    submit :signup, { email: "ada@example.test", _captcha: "token" }
    assert_response :unprocessable_entity

    assert captcha(provider: "recaptcha", recaptcha_min_score: "0.25").ok?
    submit :signup, { email: "ada@example.test", _captcha: "token" }
    assert_response :created

    assert captcha(provider: "recaptcha", recaptcha_min_score: "1.5").invalid?, "a score outside 0.0 to 1.0 can't be saved"
  end

  test "without JavaScript a form posts back to its page with the outcome, or goes to its success page" do
    post "/forms/contact", params: VALID, headers: { "Referer" => "http://www.example.com/contact" }
    assert_redirected_to "http://www.example.com/contact"
    assert_equal "sent", flash[:nibble_form]["status"]

    post "/forms/contact", params: VALID.except(:email), headers: { "Referer" => "http://www.example.com/contact" }
    assert_equal({ "email" => "The email field is required." }.keys, flash[:nibble_form]["errors"].keys)

    post "/forms/signup", params: { email: "ada@example.test" }
    assert_redirected_to "/thanks"

    post "/forms/contact", params: VALID, headers: { "Referer" => "https://evil.test/phish" }
    assert_redirected_to "/", "a post from another site never bounces the visitor back there"
  end

  test "a form that isn't in the schema doesn't exist" do
    submit :nope, VALID
    assert_response :not_found
  end
end
