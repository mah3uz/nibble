require "test_helper"
require "webmock"

class FormLimitsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include WebMock::API

  Submission = Nibble::Records::FormSubmission

  setup do
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { ActiveSupport::Cache::MemoryStore.new }
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def form_file(handle, limits, **extra)
    @nibble_themes.join("records/schema/forms/#{handle}.yml").write({
      "title" => handle.humanize, "limits" => limits, **extra.stringify_keys,
      "fields" => [ { "handle" => "email", "field" => { "type" => "text", "input_type" => "email", "required" => true } },
                    { "handle" => "name", "field" => { "type" => "text" } } ]
    }.to_yaml)
    Nibble.reset_schema!
  end

  def submit(handle, values) = post("/forms/#{handle}", params: values, as: :json)
  def definition(handle) = Nibble::Forms::Definition.call(Nibble::Forms.find(handle))

  test "a closed message written per locale reaches the visitor as the text for their locale, not as the map" do
    form_file("seminar", { "max_submissions" => 1, "closed_message" => { "en" => "All seats are taken.", "fr" => "Complet." } })
    configure_nibble_records(locales: [ { "code" => "en", "default" => true }, { "code" => "fr" } ])
    submit :seminar, { email: "ada@example.test" }

    submit :seminar, { email: "grace@example.test", _locale: "fr" }
    assert_equal({ "base" => [ "Complet." ] }, response.parsed_body["errors"])
    submit :seminar, { email: "alan@example.test" }
    assert_equal({ "base" => [ "All seats are taken." ] }, response.parsed_body["errors"])
  end

  test "a full form refuses with its closed message and tells the theme it's closed, and spam doesn't take a place" do
    form_file("seminar", { "max_submissions" => 2, "closed_message" => "All seats are taken." })

    submit :seminar, { email: "bot@example.test", _nibble_hp: "filled" }
    submit :seminar, { email: "ada@example.test" }
    assert_equal [ false, nil ], definition("seminar").values_at("closed", "closed_message")
    submit :seminar, { email: "grace@example.test" }
    assert_response :created

    submit :seminar, { email: "alan@example.test" }
    assert_response :unprocessable_entity
    assert_equal({ "base" => [ "All seats are taken." ] }, response.parsed_body["errors"])
    assert_equal 2, Submission.kept.count
    assert_equal [ true, "All seats are taken." ], definition("seminar").values_at("closed", "closed_message")
  end

  test "a schedule opens and closes the form in the site's time zone" do
    form_file("season", { "opens_at" => "2026-11-01T09:00", "closes_at" => "2026-11-02T17:00" })
    zone = Time.zone
    Time.zone = "Sydney"

    travel_to(Time.utc(2026, 10, 31, 21, 59)) { submit :season, { email: "early@example.test" } }
    assert_response :unprocessable_entity
    assert_equal [ "This form isn't taking submissions right now." ], response.parsed_body["errors"]["base"]

    travel_to(Time.utc(2026, 11, 1, 5)) do
      assert_not definition("season")["closed"], "16:00 in Sydney is open, though it would be before 09:00 in UTC"
      submit :season, { email: "ada@example.test" }
    end
    assert_response :created

    travel_to(Time.utc(2026, 11, 2, 6)) { submit :season, { email: "late@example.test" } }
    assert_response :unprocessable_entity
  ensure
    Time.zone = zone
  end

  test "unique refuses a second accepted submission with the same address, ignoring case, on that field" do
    form_file("signup_once", { "unique" => [ "email" ] })

    submit :signup_once, { email: "bot@example.test", _nibble_hp: "filled" }
    submit :signup_once, { email: "Ada@Example.test" }
    submit :signup_once, { email: "bot@example.test", name: "Real person" }
    assert_equal 2, Submission.kept.count, "a caught bot's address doesn't block the real person"

    submit :signup_once, { email: "ADA@example.TEST", name: "Ada again" }
    assert_response :unprocessable_entity
    assert_equal({ "email" => [ "The Email has already been used." ] }, response.parsed_body["errors"])
    assert_equal 2, Submission.kept.count
  end

  test "a unique value is kept only as a keyed digest, and deleting its submission frees it" do
    form_file("signup_once", { "unique" => [ "email" ] })
    submit :signup_once, { email: "ada@example.test" }

    key = Nibble::Records::FormSubmissionKey.sole
    assert_not_includes key.attributes.values.join(" "), "ada@example.test"
    Submission.sole.destroy!
    submit :signup_once, { email: "ada@example.test" }
    assert_response :created
  end

  test "a submission the form's API turned back doesn't hold its unique value, so the visitor can correct it and send again" do
    WebMock.enable!
    resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
    stub_request(:post, "https://crm.example.test/in").to_return({ status: 422, body: { errors: { name: [ "is unknown" ] } }.to_json }, { status: 201 })
    form_file("signup_once", { "unique" => [ "email" ] }, api: [ { "url" => "https://crm.example.test/in", "mode" => "sync" } ])

    submit :signup_once, { email: "ada@example.test", name: "Ad" }
    assert_equal [ "name" ], response.parsed_body["errors"].keys
    submit :signup_once, { email: "ada@example.test", name: "Ada" }
    assert_response :created
  ensure
    Nibble::Outbound::Guard.resolver = resolver
    WebMock.reset!
    WebMock.disable!
  end

  test "marking spam as not spam still refuses a duplicate of a unique value" do
    form_file("signup_once", { "unique" => [ "email" ] })
    submit :signup_once, { email: "ada@example.test", _nibble_hp: "filled" }
    submit :signup_once, { email: "ada@example.test" }

    spam = Submission.find_by!(status: "spam")
    outcome = Nibble::Forms::Submit.not_spam(Nibble::Forms.find("signup_once"), spam, user: users(:editor))
    assert_equal [ :invalid, [ "email" ] ], [ outcome.status, outcome.errors.keys ]
    assert_equal "spam", spam.reload.status
  end
end

class FormLimitsPageTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  setup do
    @site_schema = Pathname(Dir.mktmpdir("nibble-site-schema"))
    contact = YAML.safe_load_file(Rails.root.join("test/nibble_themes/starter/schema/forms/contact.yml"))
    @site_schema.join("forms").mkpath
    @site_schema.join("forms/contact.yml").write(contact.merge("limits" => { "closes_at" => "2026-11-02T17:00" }).to_yaml)
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "url" => "https://example.test", "locales" => [ { "code" => "en", "default" => true } ],
      "reserved_paths" => [ "/cp" ] }, themes_path: Rails.root.join("test/nibble_themes"), site_schema_path: @site_schema,
      content_path: Rails.root.join("test/nibble_content"), published_path: Pathname(Dir.mktmpdir("nibble-published")))
    Nibble.reset_schema!
    seed_starter_site
  end

  teardown { FileUtils.rm_rf(@site_schema) }

  def contact = page_props["props"]["contact"]

  test "a page showing a scheduled form is rendered for each visit, so it closes on time rather than when the cache empties" do
    travel_to(Time.utc(2026, 11, 2, 16, 59)) do
      get "/about"
      get "/about"
      assert_nil response.headers["X-Nibble-Cache"]
      assert_not contact["closed"]
      assert_not_includes response.headers["Surrogate-Key"].to_s, "uncacheable"
    end

    travel_to(Time.utc(2026, 11, 2, 17)) { get "/about" }
    assert_equal [ true, "This form isn't taking submissions right now." ], contact.values_at("closed", "closed_message")
  end
end
