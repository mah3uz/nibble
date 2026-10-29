require "test_helper"

class FormInputTypesTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  Submission = Nibble::Records::FormSubmission

  VALID = { "email" => "ada@example.test", "url" => "https://example.test/about?x=1", "tel" => "+61 (2) 9999-1234" }.freeze
  INVALID = {
    "email" => [ "not-an-email", "a b@example.test" ],
    "url" => [ "example.test", "javascript:alert(1)", "ftp://example.test/file", "data:text/html,hi", "mailto:a@example.test" ],
    "tel" => [ "call me", "12", "555-ABCD", "+61<script>" ]
  }.freeze

  setup do
    @store = ActiveSupport::Cache::MemoryStore.new
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { @store }
    schema = @nibble_themes.join("records", "schema")
    { "forms/inputs.yml" => { title: "Inputs", success: { message: "Thanks." }, fields: [
      { handle: "email", field: { type: "text", input_type: "email" } },
      { handle: "url", field: { type: "text", input_type: "url" } },
      { handle: "tel", field: { type: "text", input_type: "tel" } },
      { handle: "au_mobile", field: { type: "text", input_type: "tel", validate: [ "regex:/^04\\d{8}$/" ] } },
      { handle: "consent", field: { type: "toggle", required: true, inline_label: "I agree to the [privacy policy](/privacy) and [terms](javascript:alert(1))" } },
      { handle: "notice", field: { type: "note", text: "We reply **within a day**. [Read more](https://example.test/faq) or [bad](javascript:alert(1)) <script>alert(1)</script>" } }
    ] }.deep_stringify_keys,
      "collections/contacts.yml" => { title: "Contacts", blueprints: [ "contact" ] },
      "blueprints/collections/contacts/contact.yml" => { title: "Contact", tabs: { main: { sections: [ { fields: [
        { handle: "title", field: { type: "text", required: true } },
        { handle: "email", field: { type: "text", input_type: "email" } },
        { handle: "site", field: { type: "text", input_type: "url" } },
        { handle: "phone", field: { type: "text", input_type: "tel" } },
        { handle: "mobile", field: { type: "text", input_type: "tel", validate: [ "regex:/^04\\d{8}$/" ] } },
        { handle: "hint", field: { type: "note", text: "Shown in the Control Plane only." } }
      ] } ] } } }.deep_stringify_keys }.each do |relative, content|
      path = schema.join(relative)
      FileUtils.mkdir_p(path.dirname)
      path.write(content.deep_stringify_keys.to_yaml)
    end
    Nibble.reset_schema!
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def submit(values) = post("/forms/inputs", params: { consent: true, **values }, as: :json)

  def errors = response.parsed_body.fetch("errors", {})

  VALID.each do |type, good|
    test "a #{type} field on a form takes a good value and refuses bad ones, so a typo is caught before it is stored" do
      submit(type => good)
      assert_response :created

      INVALID.fetch(type).each do |bad|
        submit(type => bad)
        assert_response :unprocessable_entity, "#{bad.inspect} should be refused"
        assert errors.key?(type), "#{bad.inspect} should be refused"
      end
    end

    test "a blank #{type} field is left alone, so an optional field stays optional" do
      submit(type => "")
      assert_response :created
    end
  end

  test "an own regex replaces the built-in phone check, so a site can ask for a stricter or different number" do
    submit("au_mobile" => "0412345678")
    assert_response :created

    submit("au_mobile" => "+61 412 345 678")
    assert errors.key?("au_mobile")
  end

  test "the phone rule has its own message" do
    submit("tel" => "abc")
    assert_equal "Tel must be a valid phone number.", errors["tel"].first
  end

  test "a blueprint save refuses a bad email, URL or phone and accepts good ones and blanks" do
    bad = lifecycle_save("email" => "nope", "site" => "javascript:alert(1)", "phone" => "abc", "mobile" => "123")
    assert_not bad.ok?
    assert_equal %w[email mobile phone site], bad.errors.keys.sort

    ok = lifecycle_save(VALID.merge("site" => VALID["url"], "phone" => VALID["tel"], "mobile" => "0412345678"))
    assert ok.ok?, ok.errors.inspect
    blank = lifecycle_save("email" => "", "site" => "", "phone" => "")
    assert blank.ok?, blank.errors.inspect
  end

  test "a consent label keeps its safe links and loses the unsafe one; the plain text has only the link text" do
    field = definition["fields"].find { |item| item["handle"] == "consent" }

    assert_equal "I agree to the privacy policy and terms", field["inline_label"]
    assert_includes field["inline_label_html"], %(<a href="/privacy" rel="noopener noreferrer" target="_blank">privacy policy</a>)
    assert_not_includes field["inline_label_html"], "javascript"
    assert_includes field["inline_label_html"], "terms"
  end

  test "a label without a link is left as written" do
    Nibble::Fieldtypes::Toggle.new(Nibble::Field.new("x", { "type" => "toggle", "inline_label" => "Tick & go" })).publish_config({ "inline_label" => "Tick & go" })
      .then { |config| assert_equal({ "inline_label" => "Tick & go" }, config) }
  end

  test "a note reaches the form as sanitized HTML with safe links only" do
    html = definition["fields"].find { |item| item["handle"] == "notice" }["text_html"]

    assert_includes html, "<strong>within a day</strong>"
    assert_includes html, %(<a href="https://example.test/faq" rel="noopener">Read more</a>)
    assert_not_includes html, "javascript"
    assert_not_includes html, "<script"
    assert_not_includes html, "bad</a>"
  end

  test "a note takes nothing a visitor posts: not in the stored data, the spam copy, the refill or the mail" do
    submit("notice" => "tampered", "email" => "ada@example.test")
    assert_response :created
    assert_not Submission.sole.data.key?("notice")

    submit("notice" => "tampered", "email" => "bad")
    assert_not response.parsed_body.fetch("values", {}).key?("notice")
  end

  test "a note is not in a submission's listing columns, notification rows, or the API and agent field lists" do
    form = Nibble::Forms.find("inputs")
    assert_not_includes Nibble::Cp::SubmissionListing.new(form, user: nil).send(:fields).map(&:handle), "notice"

    notice = form.fields.get("notice")
    assert notice.display_only?
    assert_not notice.api?
    assert_nil Nibble::Operations::FieldSchema.for(notice)
    assert_equal "never", notice.fieldtype.ts_type
    assert_not_includes Nibble::TypeGenerator.new.generate, "notice"
  end

  test "a note in a blueprint stores nothing, is not in the content data, and is offered to the Control Plane" do
    result = lifecycle_save("email" => "ada@example.test", "hint" => "tampered")
    assert result.ok?

    entry = Nibble::Records::Entry.order(:id).last
    assert_not entry.data.key?("hint")

    assert_includes Nibble::Presenter.present([ entry ]).first.keys, "email"
    assert_not_includes Nibble::Presenter.present([ entry ]).first.keys, "hint"
    assert_not_includes Nibble::Presenter.new(context: Nibble::Query::Context.public, api: true).present([ entry ]).first.keys, "hint"

    publish = entry.blueprint_fields.get("hint").to_publish_h
    assert_includes publish["config"]["text_html"], "Control Plane only"
  end

  private

  def lifecycle_save(values)
    entry = Nibble::Records::Entry.new(collection: "contacts", blueprint: "contact", locale: "en")
    lifecycle(entry, :save, { "title" => "Ada #{SecureRandom.hex(3)}" }.merge(values))
  end

  def definition = Nibble::Forms::Definition.call(Nibble::Forms.find("inputs"))
end
