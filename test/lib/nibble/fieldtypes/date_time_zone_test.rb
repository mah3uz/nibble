require "test_helper"

class Nibble::Fieldtypes::DateTimeZoneTest < ActiveSupport::TestCase
  SYDNEY = { time_enabled: true, time_zone: "Australia/Sydney" }.freeze

  def fieldtype(config) = Nibble::Field.new("starts", { "type" => "date" }.merge(config.deep_stringify_keys)).fieldtype

  def errors(config, value)
    fields = Nibble::Fields.new([ { handle: "starts", field: { type: "date" }.merge(config) } ], source: "test")
    Nibble::Validator.new(fields).validate("starts" => value).errors["starts"]
  end

  test "without a time zone a date-time is read, stored and shown in UTC exactly as before" do
    plain = fieldtype(time_enabled: true)
    stored = "2026-04-04T16:30:00Z"

    assert_equal stored, plain.process(stored)
    assert_equal stored, plain.augment(stored)
    assert_equal "2026-04-04T16:30:00.000Z", plain.pre_process(stored)
    assert_equal({ "timezone" => Time.zone.tzinfo.name, "zoned" => false }, plain.preload)
    assert_equal [ "date" ], plain.rules
  end

  # One stored format for every date-time keeps text order the same as instant order, which sorting relies on.
  test "a local time is read with the offset its own date has in the zone, not today's, and stored in UTC" do
    assert_equal "2026-01-14T22:00:00Z", fieldtype(SYDNEY).process("2026-01-15T09:00")
    assert_equal "2026-07-14T23:00:00Z", fieldtype(SYDNEY).process("2026-07-15T09:00")
    assert_equal "2026-01-14T22:00:00Z", fieldtype(SYDNEY).process("2026-01-15T09:00:00+11:00"), "a time with an offset is an instant"
  end

  test "a page receives the instant in the zone, and a value across a DST change comes back at the wall time typed" do
    sydney = fieldtype(SYDNEY)

    %w[2026-01-15T09:00 2026-07-15T09:00].each do |typed|
      stored = sydney.process(typed)
      assert_equal "#{typed}:00", sydney.augment(stored).first(19)
      assert_equal stored, sydney.process(sydney.pre_process(stored)), "opening and saving again keeps it"
    end
    assert_equal "2026-07-15T09:00:00+10:00", sydney.augment("2026-07-14T23:00:00Z")
    assert_equal "2026-01-15T09:00:00+11:00", sydney.augment("2026-01-14T22:00:00Z"), "a value stored before the zone was set reads the same"
  end

  test "a time the clocks skip is refused, and the hour after it is accepted" do
    assert_equal [ "The Starts field is a time the clocks skip in Australia/Sydney. Choose a time outside the hour they go forward." ],
      errors(SYDNEY, "2026-10-04T02:30")
    assert_nil errors(SYDNEY, "2026-10-04T03:30")
    assert_equal "2026-10-03T16:30:00Z", fieldtype(SYDNEY).process("2026-10-04T03:30")
  end

  test "a time the clocks repeat is the first of the two, before they go back" do
    assert_equal "2026-04-04T15:30:00Z", fieldtype(SYDNEY).process("2026-04-05T02:30")
    assert_nil errors(SYDNEY, "2026-04-05T02:30")
  end

  test "earliest and latest dates are midnight in the field's zone" do
    config = SYDNEY.merge(earliest_date: "2026-01-01")

    assert_nil errors(config, "2026-01-01T00:30"), "half past midnight in Sydney is 13:30 UTC the day before"
    assert errors(config, "2025-12-31T23:30")
  end

  test "site names the site's own zone, and a theme and an app are told which zone it is" do
    site = Nibble::Field.new("starts", { "type" => "date", "time_enabled" => true, "time_zone" => "site" })

    assert_equal Time.zone.tzinfo.name, site.fieldtype.time_zone
    assert_equal "Australia/Sydney", Nibble::Forms::Definition.field_definition(Nibble::Field.new("starts", { "type" => "date", **SYDNEY.deep_stringify_keys }))["time_zone"]
    assert_nil Nibble::Forms::Definition.field_definition(Nibble::Field.new("starts", { "type" => "date", "time_enabled" => true }))["time_zone"]
    assert_match "read in Australia/Sydney", Nibble::Operations::FieldSchema.for(Nibble::Field.new("starts", { "type" => "date", **SYDNEY.deep_stringify_keys }))["description"]
  end

  test "check refuses a zone TZInfo doesn't know" do
    assert_equal [ "time_zone \"Mars/Olympus\" isn't an IANA time zone such as Europe/London, or site" ], fieldtype(time_enabled: true, time_zone: "Mars/Olympus").config_problems
    assert_empty fieldtype(SYDNEY).config_problems
    assert_empty fieldtype(time_enabled: true, time_zone: "site").config_problems
  end
end
