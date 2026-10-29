require "test_helper"

class Nibble::Forms::LocalizationTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  setup do
    configure_nibble_records(locales: [ { "code" => "en", "default" => true }, { "code" => "fr" }, { "code" => "de" } ])
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { @store ||= ActiveSupport::Cache::MemoryStore.new }
  end

  teardown do
    Nibble::Forms::Submit.rate_limit_store = @rate_limit_store
    I18n.backend.reload!
    I18n.config.clear_available_locales_set
  end

  def definition(locale = nil) = Nibble::Forms::Definition.call(Nibble::Forms.find("greeting"), locale:)
  def field(definition, handle) = definition["fields"].find { |item| item["handle"] == handle }

  def translate(locale, keys)
    I18n.backend.store_translations(locale, nibble: { forms: keys })
    I18n.config.clear_available_locales_set
  end

  test "the definition for a locale carries that locale's text, and the default locale's where a language is missing" do
    fr = definition("fr")

    assert_equal [ "Dites bonjour", "Merci, Dites bonjour" ], [ fr["title"], fr["success"]["message"] ]
    assert_equal [ "Vous", "Qui écrit" ], fr["sections"].first.values_at("display", "instructions")
    assert_equal [ "Courriel", "Une adresse valide", "vous@exemple.test" ], field(fr, "email").values_at("display", "instructions", "placeholder")
    assert_equal "J'accepte", field(fr, "agree")["inline_label"]

    de = definition("de")
    assert_equal [ "Say hello", "Email", "you@example.test" ], [ de["title"], field(de, "email")["display"], field(de, "email")["placeholder"] ]
    assert_equal "Say hello", definition["title"]
    assert_equal "Say hello", definition("xx")["title"]
  end

  test "option labels follow the locale while option values never change" do
    en = field(definition("en"), "topic")["options"]
    fr = field(definition("fr"), "topic")["options"]

    assert_equal [ %w[sales Sales], %w[other Other] ], en.map { |option| option.values_at("value", "label") }
    assert_equal [ %w[sales Ventes], %w[other Other] ], fr.map { |option| option.values_at("value", "label") }
  end

  test "an error names the field as the visitor's language does" do
    result = Nibble::Forms::Submit.call(Nibble::Forms.find("greeting"), {}, ip: "203.0.113.1", user_agent: "test", locale: "fr")

    assert_equal [ "Courriel is required." ], result.errors["email"]
  end

  test "a site translates a refusal under nibble.forms, and gets English where it has not" do
    form = Nibble::Forms.find("greeting")
    5.times { Nibble::Forms::Submit.call(form, { "email" => "ada@example.test" }, ip: "203.0.113.1", user_agent: "test", locale: "fr") }
    translate(:fr, rate_limited: { one: "Trop d'envois, réessayez dans %{count} minute.", other: "Trop d'envois, réessayez dans %{count} minutes." })

    fr = Nibble::Forms::Submit.call(form, {}, ip: "203.0.113.1", user_agent: "test", locale: "fr")
    en = Nibble::Forms::Submit.call(form, {}, ip: "203.0.113.1", user_agent: "test", locale: "en")

    assert_equal :rate_limited, fr.status
    assert_equal [ "Trop d'envois, réessayez dans 1 minute." ], fr.errors["base"]
    assert_equal [ "Too many submissions. Please try again in 1 minute." ], en.errors["base"]
  end

  test "the messages a theme shows for network failures come from the site's translations" do
    translate(:fr, client: { network: "Vérifiez votre connexion." })

    assert_equal "Vérifiez votre connexion.", definition("fr")["messages"]["network"]
    assert_equal "Something went wrong. Please try again.", definition("fr")["messages"]["generic"]
    assert_equal "Something went wrong. Please check your connection and try again.", definition("en")["messages"]["network"]
  end

  test "a confirmation to the visitor is in the submission's locale" do
    form = Nibble::Forms.find("greeting")
    Nibble::Forms::Submit.call(form, { "email" => "ada@example.test", "topic" => "sales" }, ip: "203.0.113.9", user_agent: "test", locale: "fr")
    perform_enqueued_jobs(only: Nibble::Jobs::NotifySubmission)

    mail = ActionMailer::Base.deliveries.last
    assert_equal "Dites bonjour", mail.subject
    assert_includes mail.text_part.body.to_s, "Ventes"
    assert_includes mail.text_part.body.to_s, "Courriel"
  end

  test "a locale map naming a language the site lacks is a check problem" do
    item = Nibble::Schema::Item.new(kind: :forms, handle: "x", parent: nil, path: "x.yml", layer: :site, data: {
      "title" => { "en" => "A", "es" => "B" }, "success" => { "message" => { "es" => "Gracias" } },
      "fields" => [ { "handle" => "a", "field" => { "type" => "select", "display" => { "it" => "A" }, "options" => [ { "value" => "x", "label" => { "pt" => "X" } } ] } } ]
    })
    found = Nibble::Forms.locale_problems(Nibble::Forms::Form.new(item:), schema: Nibble.schema, locales: %w[en fr])

    assert_equal %w[es es it pt], found.map { |message| message[/locale '(\w+)'/, 1] }
  end
end
