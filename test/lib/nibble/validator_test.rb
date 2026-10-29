require "test_helper"
require_relative "../../test_helpers/nibble_schema_helper"

class Nibble::ValidatorTest < ActiveSupport::TestCase
  include NibbleSchemaHelper

  setup { register_fake_fieldtypes }

  teardown do
    unregister_fake_fieldtypes
    Nibble::Validation.reset!
    Nibble.boot!
  end

  def fields(*definitions) = Nibble::Fields.new(definitions, source: "test")
  def field(handle, config = {}) = { handle:, field: { type: "fake_text" }.merge(config) }
  def errors(fields, values = {}, replacements: {}, **strings) = Nibble::Validator.new(fields, replacements:).validate(values.merge(strings)).errors

  test "required fields reject nil, blank strings and empty lists" do
    title = fields(field("title", required: true))

    assert_equal [ "The Title field is required." ], errors(title, {})["title"]
    assert errors(title, "title" => "   ").key?("title")
    assert_empty errors(title, "title" => "Hello")
  end

  test "optional fields are nullable: other rules only run when a value was given" do
    summary = fields(field("summary", validate: "min:10|email"))

    assert_empty errors(summary, {}), "an empty optional field must not fail min/email"
    assert_equal [ "The Summary field must be at least 10 characters.", "The Summary field must be a valid email address." ],
      errors(summary, "summary" => "short")["summary"]
  end

  test "size rules measure characters, numbers or item counts depending on the value" do
    assert errors(fields(field("code", validate: [ "max:3" ])), "code" => "abcd").key?("code")
    assert_empty errors(fields(field("rating", validate: [ "numeric", "max:5" ])), "rating" => "4.5")
    assert_equal [ "The Rating field must not be greater than 5." ], errors(fields(field("rating", validate: [ "numeric", "max:5" ])), "rating" => 9)["rating"]
    assert_equal [ "The Tags field must not have more than 2 items." ], errors(fields(field("tags", validate: [ "max:2" ])), "tags" => %w[a b c])["tags"]
  end

  test "a field's own message replaces the default for its rule, with the same placeholders" do
    plain = errors(fields(field("code", validate: [ "max:3" ], messages: { max: "%{attribute} is too long, %{max} at most" })), "code" => "abcd")
    sized = errors(fields(field("amount", validate: [ "numeric", "min:500" ], messages: { min: "Amounts start at $%{min}" })), "amount" => 5)

    assert_equal [ "Code is too long, 3 at most" ], plain["code"]
    assert_equal [ "Amounts start at $500" ], sized["amount"]
    assert_equal [ "The Code field must not be greater than 3 characters." ], errors(fields(field("code", validate: [ "max:3" ])), "code" => "abcd")["code"]
    assert_equal [ "The Code field is required." ], errors(fields(field("code", required: true, messages: { max: "Nope" })), {})["code"]
  end

  test "a localized message follows the locale and falls back to the default locale's entry" do
    defn = fields(field("amount", validate: [ "numeric", "min:2000" ], messages: { min: { en: "At least $2,000", fr: "Au moins 2 000 $" } }))
    validate = ->(locale) { Nibble::Validator.new(defn, locale:).validate("amount" => 1).errors["amount"] }

    assert_equal [ "Au moins 2 000 $" ], validate.("fr")
    assert_equal [ "At least $2,000" ], validate.("en")
    assert_equal [ "At least $2,000" ], validate.("de")
    assert_equal [ "At least $2,000" ], validate.(nil)
  end

  test "fields hidden by their conditions are neither validated nor blocking, unless always_save" do
    link = fields(
      field("type"),
      field("url", required: true, if: { type: "external" }),
      field("note", required: true, if: { type: "external" }, always_save: true)
    )

    result = errors(link, "type" => "entry")
    assert_not result.key?("url"), "an editor can't fill a field they can't see"
    assert result.key?("note")
    assert errors(link, "type" => "external").key?("url")
  end

  test "a field hidden by its condition keeps the value it was sent, validated or not" do
    link = fields(field("type"), field("url", validate: "max:5", if: { type: "external" }), field("note", always_save: true, if: { type: "external" }))

    result = Nibble::Validator.new(link).validate("type" => "entry", "url" => "https://example.test/long", "note" => "kept")

    assert_empty result.errors
    assert_equal [ "https://example.test/long", "kept" ], result.values.values_at("url", "note")
  end

  test "required can wait on a condition: blank passes while it fails and is refused while it passes" do
    contact = fields(field("by"), field("phone", required: { if: { by: "phone" } }), field("other", required: { unless: { by: "phone" } }))

    assert_empty errors(contact, "by" => "email", "other" => "x")
    assert_equal [ "The Phone field is required." ], errors(contact, "by" => "phone", "other" => "x")["phone"]
    assert_equal [ "The Other field is required." ], errors(contact, "by" => "email", "phone" => "1")["other"]
    assert_empty errors(contact, "by" => "phone", "phone" => "0400")
  end

  test "a conditionally required toggle must be on once the condition passes" do
    terms = fields(field("by"), { handle: "consent", field: { type: "toggle", required: { if: { by: "phone" } } } })

    assert_empty errors(terms, "by" => "email", "consent" => false)
    assert_equal [ "The Consent field is required." ], errors(terms, "by" => "phone", "consent" => false)["consent"]
    assert_empty errors(terms, "by" => "phone", "consent" => true)
  end

  test "a conditionally required field that is itself hidden is not required" do
    contact = fields(field("by"), field("phone", required: { if: { by: "phone" } }, unless: { by: "phone" }))

    assert_empty errors(contact, "by" => "phone")
  end

  test "computed fields are set by the server and never validated" do
    assert_empty errors(fields(field("total", required: true, visibility: "computed")), {})
  end

  # An unticked box is a value, so without this a required consent box could never be refused.
  test "a required toggle must be on, while false still fills a required field of another type" do
    consent = fields({ handle: "consent", field: { type: "toggle", required: true } })

    [ false, "false", "0", 0, nil ].each do |off|
      assert_equal [ "The Consent field is required." ], errors(consent, "consent" => off)["consent"], "#{off.inspect} is off"
    end
    [ true, "true", "1", "on" ].each { |on| assert_empty errors(consent, "consent" => on), "#{on.inspect} is on" }
    assert_empty errors(fields({ handle: "consent", field: { type: "toggle" } }), "consent" => false)
    assert_empty errors(fields(field("answer", required: true)), "answer" => false)
  end

  test "required_if compares against another field, including booleans" do
    video = fields(field("has_video"), field("video_url", validate: [ "required_if:has_video,true", "url" ]))

    assert_equal [ "The Video url field is required when has video is true." ], errors(video, "has_video" => true)["video_url"]
    assert_empty errors(video, "has_video" => false)
    assert errors(video, "has_video" => true, "video_url" => "not a url")["video_url"].first.include?("valid URL")
  end

  test "rules inside repeated rows are scoped to their row with {this}" do
    rows = fields({ handle: "links", field: { type: "fake_rows", fields: [
      { handle: "kind", field: { type: "fake_text" } },
      { handle: "url", field: { type: "fake_text", validate: [ "required_if:{this}.kind,external" ] } }
    ] } })

    result = errors(rows, "links" => [ { "kind" => "external" }, { "kind" => "entry" }, { "kind" => "external", "url" => "https://x.test" } ])
    assert_equal [ "links.0.url" ], result.keys
  end

  test "record replacements fill placeholders in rule parameters" do
    Nibble::Validation.register("not_self") { |value, params:, **| "The %{attribute} can't point at itself." if value.to_s == params.first }

    parent = fields(field("parent", validate: [ "not_self:{id}" ]))
    assert_equal [ "The Parent can't point at itself." ], errors(parent, { "parent" => "42" }, replacements: { id: 42 })["parent"]
    assert_empty errors(parent, { "parent" => "7" }, replacements: { id: 42 })
  end

  test "regex rules accept delimited patterns with flags and anchor to the whole value" do
    code = fields(field("code", validate: [ "regex:/^[a-z]+$/i" ]))

    assert_empty errors(code, "code" => "AbC")
    assert errors(code, "code" => "abc\nevil").key?("code"), "anchors must not match per line"
  end

  test "dates compare against keywords or other fields" do
    event = fields(field("starts_at", validate: [ "date" ]), field("ends_at", validate: [ "after:starts_at" ]))

    assert_empty errors(event, "starts_at" => "2026-10-01 10:00", "ends_at" => "2026-10-01 12:00")
    assert_equal [ "The Ends at field must be a date after starts_at." ], errors(event, "starts_at" => "2026-10-01 10:00", "ends_at" => "2026-09-30")["ends_at"]
    assert errors(fields(field("expires", validate: [ "after:tomorrow" ])), "expires" => Time.current.iso8601).key?("expires")
  end

  test "in, not_in, alpha_dash, starts_with and case rules" do
    assert errors(fields(field("size", validate: [ "in:s,m,l" ])), "size" => "xl").key?("size")
    assert_empty errors(fields(field("sizes", validate: [ "in:s,m,l" ])), "sizes" => %w[s l])
    assert errors(fields(field("handle", validate: [ "not_in:admin,api" ])), "handle" => "api").key?("handle")
    assert errors(fields(field("slug", validate: [ "alpha_dash" ])), "slug" => "hello world").key?("slug")
    assert errors(fields(field("path", validate: [ "starts_with:/" ])), "path" => "about").key?("path")
    assert errors(fields(field("code", validate: [ "lowercase" ])), "code" => "Abc").key?("code")
  end

  test "unknown rules fail loud rather than silently passing" do
    assert_raises(Nibble::Error, match: /unknown validation rule 'postcode'/) do
      errors(fields(field("zip", validate: [ "postcode" ])), "zip" => "2000")
    end
  end
end
