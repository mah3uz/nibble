require "test_helper"

class FormContentOptionsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper

  Submission = Nibble::Records::FormSubmission
  ENQUIRY = { title: "Enquiry", success: { message: "Thanks." }, fields: [
    { handle: "email", field: { type: "text", input_type: "email" } },
    { handle: "article", field: { type: "select", options: { from: "entries:articles", sort: "title" } } },
    { handle: "section", field: { type: "select", options: { from: "entries:docs", where: { parent_id: { null: true } } } } },
    { handle: "page", field: { type: "select", options: { from: "entries:docs", parent: "section" }, messages: { in: "Pick a page in that section." } } },
    { handle: "topics", field: { type: "checkboxes", options: { from: "terms:tags" } } },
    { handle: "reads", field: { type: "checkboxes", options: { from: "entries:articles", parent: { field: "topics", by: "tags" } } } },
    { handle: "private", field: { type: "select", encrypt: true, options: { from: "entries:articles" } } }
  ] }.freeze

  setup do
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { @store ||= ActiveSupport::Cache::MemoryStore.new }
    @nibble_themes.join("records/schema/forms/enquiry.yml").write(ENQUIRY.deep_stringify_keys.to_yaml)
    Nibble.reset_schema!
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def definition(locale = nil) = Nibble::Forms::Definition.call(Nibble::Forms.find("enquiry"), locale:)
  def options(handle, locale = nil) = definition(locale)["fields"].find { |field| field["handle"] == handle }["options"]
  def enquire(values) = post("/forms/enquiry", params: { email: "ada@example.test" }.merge(values), as: :json)
  def refusal(handle) = response.parsed_body.dig("errors", handle.to_s)&.first
  def stored_text(id) = Submission.connection.select_one("SELECT * FROM form_submissions WHERE id = #{id.to_i}").values.join(" ")
  def article(title, slug, **attrs) = publish_entry(create_entry("articles", { "title" => title, "slug" => slug, **attrs }))

  def doc(title, slug, parent: nil)
    entry = create_entry("docs", { "title" => title, "slug" => slug, "parent_id" => parent&.id }.compact)
    lifecycle(entry, :submit)
    lifecycle(entry.reload, :approve)
    publish_entry(entry.reload)
  end

  test "a published entry is offered and accepted, while a draft or a made-up value is refused, so a post can't name what the visitor wasn't shown" do
    article("Pricing", "pricing")
    create_entry("articles", { "title" => "Secret launch", "slug" => "secret-launch" })

    assert_equal [ { "value" => "pricing", "label" => "Pricing" } ], options("article")

    enquire article: "secret-launch"
    assert_response :unprocessable_content
    assert_equal "Choose one of the options for Article.", refusal(:article)

    enquire article: "anything"
    assert_response :unprocessable_content

    enquire article: "pricing"
    assert_response :created
    assert_equal "pricing", Submission.sole.data["article"]
  end

  test "a visitor in another locale is offered that locale's entries and titles, and can send one of them" do
    configure_nibble_records(locales: [ { "code" => "en", "default" => true }, { "code" => "fr" } ])
    article("Pricing", "pricing")
    publish_entry(lifecycle(Nibble::Records::Entry.new(collection: "articles", locale: "fr"), :create, { "title" => "Tarifs", "slug" => "tarifs" }).record)

    assert_equal [ [ "tarifs", "Tarifs" ] ], options("article", "fr").map { |option| option.values_at("value", "label") }
    assert_equal [ [ "pricing", "Pricing" ] ], options("article", "en").map { |option| option.values_at("value", "label") }

    post "/forms/enquiry", params: { email: "ada@example.test", article: "tarifs", _locale: "fr" }, as: :json
    assert_response :created
  end

  test "a page is offered under its section, and one from another section is refused with the field's own message" do
    billing = doc("Billing", "billing")
    support = doc("Support", "support")
    doc("Invoices", "invoices", parent: billing)
    doc("Outages", "outages", parent: support)

    assert_equal [ "billing", "support" ], options("section").map { |option| option["value"] }.sort
    assert_includes options("page"), { "value" => "invoices", "label" => "Invoices", "parents" => [ "billing" ] }

    enquire section: "support", page: "invoices"
    assert_response :unprocessable_content
    assert_equal "Pick a page in that section.", refusal(:page)

    enquire section: "billing", page: "invoices"
    assert_response :created
  end

  test "an article is offered under each topic it's tagged with, and any of several chosen topics lets it through" do
    news = create_term("News")
    guides = create_term("Guides")
    events = create_term("Events")
    article("Launch", "launch", "tags" => [ news.id ])
    article("How to", "how-to", "tags" => [ guides.id, news.id ])
    article("Meetup", "meetup", "tags" => [ events.id ])

    assert_equal [ "guides", "news" ], options("reads").find { |option| option["value"] == "how-to" }["parents"].sort

    enquire topics: %w[news guides], reads: %w[launch how-to]
    assert_response :created

    enquire topics: %w[news guides], reads: %w[launch meetup]
    assert_response :unprocessable_content
    assert refusal(:reads)
  end

  test "staff read the title an entry has now, and the one it had when it was sent once the entry is gone" do
    pricing = article("Pricing", "pricing")
    enquire article: "pricing"
    assert_equal({ "article" => { "pricing" => "Pricing" } }, Submission.sole.labels)

    sign_in_as users(:editor)
    publish_entry(pricing.reload, "title" => "Plans and pricing")
    get "/cp/forms/enquiry.csv"
    assert_equal "Plans and pricing", CSV.parse(response.body, headers: true).first["Article"]

    lifecycle(pricing.reload, :trash)
    get "/cp/forms/enquiry.csv"
    assert_equal "Pricing", CSV.parse(response.body, headers: true).first["Article"]
    get "/cp/forms/enquiry/submissions/#{Submission.sole.id}"
    meta = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]["meta"]
    assert_includes meta["article"]["options"], { "value" => "pricing", "label" => "Pricing" }
  end

  test "an encrypted choice keeps its label sealed as well, so the database never shows what was chosen" do
    article("Redundancy advice", "redundancy-advice")
    enquire private: "redundancy-advice"

    submission = Submission.sole
    assert_not_includes stored_text(submission.id), "Redundancy advice"
    assert_not_includes stored_text(submission.id), "redundancy-advice"
    assert_equal({ "redundancy-advice" => "Redundancy advice" }, submission.labels["private"])
  end

  test "erasing a person removes the labels kept with their submissions" do
    article("Pricing", "pricing")
    enquire article: "pricing"
    assert_equal({ "article" => { "pricing" => "Pricing" } }, Submission.sole.labels)

    sign_in_as users(:admin)
    delete "/cp/personal-data", params: { email: "ada@example.test" }
    assert_empty Submission.all
    assert_nil Submission.connection.select_value("SELECT id FROM form_submissions WHERE labels LIKE '%Pricing%'")
  end
end
