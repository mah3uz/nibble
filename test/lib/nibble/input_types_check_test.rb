require "test_helper"

class Nibble::InputTypesCheckTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  def write_schema(contact_fields)
    schema = @nibble_themes.join("records", "schema")
    { "collections/contacts.yml" => { "title" => "Contacts", "blueprints" => [ "contact" ] },
      "blueprints/collections/contacts/contact.yml" => { "title" => "Contact", "tabs" => { "main" => { "sections" => [ { "fields" => [
        { "handle" => "title", "field" => { "type" => "text" } }, *contact_fields
      ] } ] } } } }.each do |relative, content|
      path = schema.join(relative)
      FileUtils.mkdir_p(path.dirname)
      path.write(content.to_yaml)
    end
    Nibble.reset_schema!
  end

  def store(data) = Nibble::Records::Entry.create!(collection: "contacts", blueprint: "contact", locale: "en", title: data["title"], slug: data["title"].parameterize, data:)

  # Entries saved when email, url and tel took anything fail their next save; the check names them without stopping a deploy.
  test "nibble:check warns which saved entries hold an email, URL or phone that now fails, with their ids" do
    write_schema([ { "handle" => "email", "field" => { "type" => "text", "input_type" => "email" } },
                   { "handle" => "site", "field" => { "type" => "text", "input_type" => "url" } },
                   { "handle" => "phone", "field" => { "type" => "text", "input_type" => "tel" } },
                   { "handle" => "mobile", "field" => { "type" => "text", "input_type" => "tel", "validate" => [ "regex:/^04\\d{8}$/" ] } } ])
    bad = store("title" => "Bad", "email" => "nope", "site" => "example.test", "phone" => "call me", "mobile" => "0412345678")
    good = store("title" => "Good", "email" => "a@example.test", "site" => "https://example.test", "phone" => "+61 2 9999 1234", "mobile" => "0412345678")
    blank = store("title" => "Blank", "email" => "")
    regex = store("title" => "Regex", "mobile" => "+61 412 345 678")

    messages = Nibble::Check.run.warnings.select { |warning| warning.source == "collection 'contacts'" }.map(&:message)

    assert(messages.any? { |message| message.include?("(#{bad.id}) has a value in the email field 'email'") })
    assert(messages.any? { |message| message.include?("(#{bad.id}) has a value in the url field 'site'") })
    assert(messages.any? { |message| message.include?("(#{bad.id}) has a value in the tel field 'phone'") })
    assert(messages.any? { |message| message.include?("(#{regex.id}) has a value in the tel field 'mobile'") })
    assert_equal 4, messages.size
    assert_not(messages.any? { |message| message.include?(good.id.to_s) || message.include?(blank.id.to_s) })
  end

  test "nibble:check refuses a note that is required, hidden, encrypted or has a default, since it stores nothing" do
    write_schema([ { "handle" => "a", "field" => { "type" => "note", "text" => "Hi", "required" => true } },
                   { "handle" => "b", "field" => { "type" => "note", "text" => "Hi", "default" => "x" } },
                   { "handle" => "c", "field" => { "type" => "note", "text" => "Hi", "hidden" => true } },
                   { "handle" => "d", "field" => { "type" => "note", "text" => "Hi", "encrypt" => true } },
                   { "handle" => "e", "field" => { "type" => "note", "text" => "Hi" } } ])

    problems = Nibble::Check.run.problems.map(&:message).grep(/is a note/)

    assert_equal %w[a b c d].map { |handle| "field '#{handle}' is a note, which only displays text: it can't be required, hidden, encrypted or have a default" }.sort, problems.sort
  end
end
