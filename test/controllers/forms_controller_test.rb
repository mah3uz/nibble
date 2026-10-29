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

  test "a hidden field takes the page's query from the form's action, a fixed value the visitor can't change, and is stored like the rest" do
    post "/forms/tracked?utm_source=news", params: { name: "Ada", channel: "forged", source: "" }, as: :json

    assert_response :created
    assert_equal({ "name" => "Ada", "source" => "news", "channel" => "web", "campaign" => "organic" }, Submission.sole.data)
  end

  test "a hidden field is validated like any other" do
    post "/forms/tracked?utm_source=#{'x' * 11}", params: { name: "Ada" }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "source" ], response.parsed_body["errors"].keys
  end

  test "invalid input comes back keyed by field and nothing is stored" do
    submit :contact, VALID.merge(email: "not-an-email", message: "x" * 501, topic: "billing").except(:name)

    assert_response :unprocessable_entity
    assert_equal %w[email message name topic], response.parsed_body["errors"].keys.sort
    assert_empty Submission.all
  end

  test "a required consent box left unticked is refused, so no submission arrives without the consent it asks for" do
    path = @nibble_themes.join("records", "schema", "forms", "consent.yml")
    path.write({ "title" => "Consent", "fields" => [ { "handle" => "agree", "field" => { "type" => "toggle", "required" => true } } ] }.to_yaml)
    Nibble.reset_schema!

    post "/forms/consent", params: { agree: "false" }, headers: { "Accept" => "application/json" }
    assert_response :unprocessable_entity
    assert_equal [ "Agree is required." ], response.parsed_body["errors"]["agree"]
    submit :consent, { agree: false }
    assert_response :unprocessable_entity
    assert_empty Submission.all

    submit :consent, { agree: true }
    assert_response :created
    assert_equal({ "agree" => true }, Submission.sole.data)
  end

  test "a field's own message is what a visitor sees when its rule fails" do
    submit :callback, { phone: "12345" }

    assert_response :unprocessable_entity
    assert_equal [ "Enter an Australian mobile number" ], response.parsed_body["errors"]["phone"]
  end

  test "a field's step message is what a visitor sees off the step, in the submission's locale" do
    submit :worded_pledge, { amount: 2250 }
    assert_equal [ "Steps of $500 from $2000" ], response.parsed_body["errors"]["amount"]

    configure_nibble_records(locales: [ { "code" => "en", "default" => true }, { "code" => "fr" } ])
    submit :worded_pledge, { amount: 2250, _locale: "fr" }
    assert_equal [ "Par tranches de 500" ], response.parsed_body["errors"]["amount"]
  end

  test "a filled honeypot looks like success to the bot, and keeps its values as spam so a wrongly caught enquiry can be read" do
    submit :contact, VALID.merge(_nibble_hp: "http://spam.test", admin: true, topic: { "$gt" => "" })

    assert_response :created
    assert_equal [ "spam", VALID.except(:topic).stringify_keys ], Submission.sole.values_at(:status, :data),
      "only the form's own fields are kept, and only as plain values"
    assert_empty Nibble::Records::OutboxEvent.where(name: "form.submitted")
    assert_no_enqueued_jobs only: [ Nibble::Jobs::NotifySubmission, Nibble::Jobs::DeliverSubmission ]
  end

  test "a burst of submissions from one address is cut off at the form's rate limit" do
    5.times { submit :contact, VALID }
    submit :contact, VALID

    assert_response :too_many_requests
    assert_equal 5, Submission.count
  end

  test "without JavaScript a failed post hands back what the visitor typed, except hidden fields, and only while it fits the cookie" do
    referer = { "Referer" => "http://www.example.com/contact" }
    post "/forms/contact", params: VALID.except(:email).merge(_nibble_hp: ""), headers: referer
    assert_equal({ "name" => "Ada", "topic" => "sales", "message" => "Hello there" }, flash[:nibble_form]["values"])

    post "/forms/contact", params: VALID.except(:email).merge(message: "x" * 3000), headers: referer
    assert_equal %w[name topic], flash[:nibble_form]["values"].keys, "a value that would overflow the cookie is dropped, not the redirect"

    post "/forms/tracked?utm_source=news", params: { source: "typed", channel: "typed" }, headers: referer
    assert_equal({}, flash[:nibble_form]["values"])

    post "/forms/contact", params: VALID, headers: referer
    assert_nil flash[:nibble_form]["values"]
  end

  test "a visitor correcting a form isn't locked out: only accepted submissions use up the limit" do
    8.times { submit :contact, VALID.except(:email) }
    assert_response :unprocessable_entity

    5.times { submit :contact, VALID }
    assert_response :created
    submit :contact, VALID
    assert_response :too_many_requests
    assert_equal 5, Submission.count
  end

  test "a flood of invalid posts is still cut off, at ten times the limit" do
    travel_to Time.zone.at((Time.current.to_i / 600) * 600 + 30)
    50.times { submit :contact, VALID.except(:email) }
    assert_response :unprocessable_entity

    submit :contact, VALID
    assert_response :too_many_requests
  end

  test "the refusal says how long to wait for the form's own window" do
    # Limits count in fixed windows, so the wait depends on how far into one the request lands.
    travel_to Time.zone.at((Time.current.to_i / 600) * 600 + 30)
    2.times { submit :tracked, { name: "Ada" } }
    submit :tracked, { name: "Ada" }

    assert_response :too_many_requests
    assert_match(/try again in 10 minutes\./, response.parsed_body["errors"]["base"].first)

    submit :contact, VALID
    5.times { submit :contact, VALID }
    assert_equal "Too many submissions. Please try again in 1 minute.", response.parsed_body["errors"]["base"].first
  end

  test "a form that doesn't store keeps nothing" do
    captcha(provider: "turnstile")
    stub_request(:post, TURNSTILE).to_return(body: { success: true }.to_json)

    submit :signup, { email: "ada@example.test", _captcha: "good" }

    assert_response :created
    assert_equal "/thanks", response.parsed_body["redirect"]
    assert_empty Submission.all
  end

  test "a CAPTCHA form with no keys refuses everyone and logs it, so removing the keys can't silently open the form to spam" do
    logged = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(logged)

    submit :signup, { email: "ada@example.test", _captcha: "anything" }

    assert_response :unprocessable_entity
    assert_equal [ "This form can't take submissions right now. Please try again later." ], response.parsed_body["errors"]["base"]
    assert_includes logged.string, "signup"
  ensure
    Rails.logger = previous
  end

  test "with keys set, a missing token is refused and a valid one accepted" do
    captcha(provider: "turnstile")
    stub_request(:post, TURNSTILE).with(body: hash_including("response" => "good")).to_return(body: { success: true }.to_json)

    submit :signup, { email: "ada@example.test" }
    assert_response :unprocessable_entity
    assert_equal [ "Please confirm you're not a robot." ], response.parsed_body["errors"]["base"]
    submit :signup, { email: "ada@example.test", _captcha: "good" }
    assert_response :created
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

  # The provider's verify URL is fixed in Nibble, so a site that lists only its own API still checks CAPTCHAs.
  test "a CAPTCHA is verified on a site whose outbound allowlist names only its own API" do
    captcha(provider: "recaptcha")
    stub_request(:post, "https://www.google.com/recaptcha/api/siteverify").to_return(body: { success: true, score: 0.9 }.to_json)
    configure_nibble_records(outbound: { "allowed_hosts" => [ "api.crm.example" ] })

    submit :signup, { email: "ada@example.test", _captcha: "token" }

    assert_response :success
  end

  test "without JavaScript a form posts back to its page with the outcome, or goes to its success page" do
    post "/forms/contact", params: VALID, headers: { "Referer" => "http://www.example.com/contact" }
    assert_redirected_to "http://www.example.com/contact"
    assert_equal "sent", flash[:nibble_form]["status"]

    post "/forms/contact", params: VALID.except(:email), headers: { "Referer" => "http://www.example.com/contact" }
    assert_equal({ "email" => "email is required." }.keys, flash[:nibble_form]["errors"].keys)

    captcha(provider: "turnstile")
    stub_request(:post, TURNSTILE).to_return(body: { success: true }.to_json)
    post "/forms/signup", params: { email: "ada@example.test", _captcha: "good" }
    assert_redirected_to "/thanks"

    post "/forms/contact", params: VALID, headers: { "Referer" => "https://evil.test/phish" }
    assert_redirected_to "/", "a post from another site never bounces the visitor back there"
  end

  test "a form that isn't in the schema doesn't exist" do
    submit :nope, VALID
    assert_response :not_found
  end
end
