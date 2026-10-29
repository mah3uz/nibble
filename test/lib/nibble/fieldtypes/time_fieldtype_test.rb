require "test_helper"

class Nibble::Fieldtypes::TimeFieldtypeTest < ActiveSupport::TestCase
  setup { @themes = Pathname(Dir.mktmpdir("nibble-themes")) }
  teardown { FileUtils.rm_rf(@themes) }

  def fieldtype(config = {}) = Nibble::Field.new("opens", { "type" => "time" }.merge(config.deep_stringify_keys)).fieldtype

  def errors(config, value)
    fields = Nibble::Fields.new([ { handle: "opens", field: { type: "time" }.merge(config) } ], source: "test")
    Nibble::Validator.new(fields).validate("opens" => value).errors["opens"]
  end

  def check_problems(yaml)
    path = @themes.join("check", "schema", "fieldsets", "hours.yml")
    FileUtils.mkdir_p(path.dirname)
    path.write(yaml)
    config = Nibble::Config.new({ "theme" => "check", "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: @themes)
    Nibble::Check.run(config:, static: true).problems.map(&:message).grep(/field 'opens'/)
  end

  test "a time is stored on the 24-hour clock, to the minute unless seconds are on" do
    assert_equal "09:30", fieldtype.process("09:30")
    assert_equal "09:30", fieldtype.process("09:30:45"), "a browser that sends seconds can't store more than the field shows"
    assert_equal "09:30:45", fieldtype(seconds: true).process("09:30:45")
    assert_equal "09:30:00", fieldtype(seconds: true).process("09:30")
    assert_nil fieldtype.process("")
  end

  test "anything but a 24-hour time is refused, so a page never has to guess what 9.30 or noon meant" do
    [ "9:30", "24:00", "12:60", "noon", "09:30 pm", "09:30:5" ].each do |value|
      assert_match "must be a time of day on the 24-hour clock, such as 14:30", errors({}, value)&.first, value
    end
    assert_nil errors({}, "00:00")
    assert_nil errors({}, "23:59:59")
  end

  test "earliest and latest bound the time, inclusively, and say the bound they broke" do
    config = { earliest: "09:00", latest: "17:30" }

    assert_equal [ "Opens must be 09:00 or later." ], errors(config, "08:59")
    assert_equal [ "Opens must be 17:30 or earlier." ], errors(config, "17:30:01")
    assert_nil errors(config, "09:00")
    assert_nil errors(config, "17:30")
  end

  test "check refuses a bound YAML read as a number, which an unquoted 09:30 is, and bounds out of order" do
    found = check_problems(<<~YAML)
      title: Hours
      fields:
        - handle: opens
          field: { type: time, earliest: 09:30, latest: "08:00", default: "7am" }
    YAML

    assert_includes found, "field 'opens' earliest must be a time written in quotes, such as '09:30'"
    assert_includes found, "field 'opens' default must be a time written in quotes, such as '09:30'"
    assert_equal [ "field 'opens' earliest 09:30 is after latest 08:00" ],
      check_problems(%(title: Hours\nfields:\n  - { handle: opens, field: { type: time, earliest: "09:30", latest: "08:00" } }\n))
  end

  test "an app is told the shape a time is written in" do
    schema = Nibble::Operations::FieldSchema.for(Nibble::Field.new("opens", { "type" => "time" }))

    assert_equal "string", schema["type"]
    assert_match Regexp.new(schema["pattern"]), "17:45"
    assert_no_match Regexp.new(schema["pattern"]), "5:45"
  end
end
