require "test_helper"

class Nibble::RequiredToggleTest < ActiveSupport::TestCase
  include NibbleRecordsHelper

  setup do
    schema = @nibble_themes.join("records", "schema")
    { "collections/policies.yml" => { "title" => "Policies", "blueprints" => [ "policy" ] },
      "blueprints/collections/policies/policy.yml" => { "title" => "Policy", "tabs" => { "main" => { "sections" => [ { "fields" => [
        { "handle" => "title", "field" => { "type" => "text", "required" => true } },
        { "handle" => "reviewed", "field" => { "type" => "toggle", "required" => true } },
        { "handle" => "featured", "field" => { "type" => "toggle" } }
      ] } ] } } },
      "globals/legal.yml" => { "title" => "Legal", "blueprint" => { "title" => "Legal", "tabs" => { "main" => { "sections" => [ { "fields" => [
        { "handle" => "approved", "field" => { "type" => "toggle", "validate" => [ "required" ] } }
      ] } ] } } } } }.each do |relative, content|
      path = schema.join(relative)
      FileUtils.mkdir_p(path.dirname)
      path.write(content.to_yaml)
    end
    Nibble.reset_schema!
  end

  def publish(entry) = lifecycle(entry, :publish, "published_at" => 1.day.ago.utc.iso8601)

  test "an entry can't be published with a required toggle off, and an optional toggle off doesn't stop it" do
    entry = create_entry("policies", { "title" => "Privacy", "reviewed" => false, "featured" => false })

    result = publish(entry)
    assert_not result.ok?
    assert_equal [ "Reviewed is required." ], result.errors["reviewed"]

    lifecycle(entry, :save, "title" => "Privacy", "reviewed" => true, "featured" => false)
    assert publish(entry.reload).ok?
    assert_equal false, entry.reload.data["featured"]
  end

  test "a global set can't be saved with a required toggle off" do
    result = lifecycle(Nibble::Records::GlobalSet.new(handle: "legal", locale: "en"), :save, "approved" => false)

    assert_not result.ok?
    assert_equal [ "Approved is required." ], result.errors["approved"]
  end

  # Records saved before required meant "on" fail their next save; the check names them without stopping a deploy.
  test "nibble:check warns how many records hold a required toggle that is off, naming the field" do
    create_entry("policies", { "title" => "Off", "reviewed" => false })
    create_entry("policies", { "title" => "Missing" })
    create_entry("policies", { "title" => "On", "reviewed" => true })
    Nibble::Records::GlobalSet.create!(handle: "legal", locale: "en", data: { "approved" => false })

    check = Nibble::Check.run
    warnings = check.warnings.to_h { |warning| [ warning.source, warning.message ] }

    assert_equal "2 entries have the required toggle 'reviewed' switched off, so they can't be published until it is switched on " \
                 "or the field is made optional", warnings["collection 'policies'"]
    assert_equal "1 record has the required toggle 'approved' switched off, so it can't be saved until it is switched on " \
                 "or the field is made optional", warnings["global 'legal'"]
    assert_not(check.problems.any? { |problem| problem.message.include?("required toggle") })
    assert_not(check.warnings.any? { |warning| warning.message.include?("'featured'") })
  end
end
