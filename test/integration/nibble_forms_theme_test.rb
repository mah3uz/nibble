require "test_helper"

class NibbleFormsThemeTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  setup do
    seed_starter_site
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { ActiveSupport::Cache::MemoryStore.new }
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def contact = page_props["props"]["contact"]

  test "a view gets the form's public definition: fields with their display config, and nothing server-only" do
    get "/about"
    assert_response :success

    assert_equal [ "contact", "/forms/contact", "_nibble_hp", nil ], contact.values_at("handle", "action", "honeypot", "captcha"),
      "CAPTCHA is off until the site configures a provider"
    email, topic, attachment = contact["fields"]
    assert_equal({ "handle" => "email", "type" => "text", "display" => "Email", "instructions" => nil, "required" => true,
                   "input_type" => "email", "placeholder" => "you@example.com" }, email.except("character_limit"))
    assert_equal [ { "value" => "sales", "label" => "Sales" }, { "value" => "support", "label" => "Support" } ], topic["options"]
    assert_equal [ 1, 2, [ "pdf" ] ], attachment.values_at("max_files", "max_file_size", "extensions")
    assert_not_includes response.body, "regex:/@/", "validation rules stay on the server"
  end

  test "the site key reaches the theme once CAPTCHA is configured, never the secret" do
    ok Nibble::Lifecycle.call(Nibble::Records::GlobalSet.new(handle: "integrations", locale: "en"), :save,
      { "captcha_provider" => "turnstile", "captcha_site_key" => "site-key-1", "captcha_secret_key" => { "plain" => "very-secret" } })

    get "/about"
    assert_equal({ "provider" => "turnstile", "site_key" => "site-key-1" }, contact["captcha"])
    assert_not_includes response.body, "very-secret"
  end

  test "without JavaScript the outcome of a post shows on the page it came from, and isn't cached for anyone else" do
    process :post, "/forms/contact", params: { email: "not an email" }, headers: { "Referer" => "http://www.example.com/about" }
    follow_redirect!
    assert_equal "invalid", contact.dig("result", "status")
    assert_equal [ "email" ], contact.dig("result", "errors").keys

    get "/about"
    assert_nil contact["result"], "the outcome shows once"
    get "/about"
    assert_equal "hit", response.headers["X-Nibble-Cache"]
    assert_nil contact["result"]
  end

  test "a sidecar can't use query options on a form source, or name a form that doesn't exist" do
    error = assert_raises(Nibble::Query::Invalid) { Nibble::Query::Spec.parse({ "from" => "form:contact", "limit" => 3 }) }
    assert_match "isn't supported by form sources", error.message
    assert_raises(Nibble::Query::Invalid) { Nibble::Query::Spec.parse({ "from" => "form:nope" }) }
  end
end
