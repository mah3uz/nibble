require "test_helper"

class Nibble::Fieldtypes::ColorFieldtypeTest < ActiveSupport::TestCase
  setup { @themes = Pathname(Dir.mktmpdir("nibble-themes")) }
  teardown { FileUtils.rm_rf(@themes) }

  SWATCHES = { swatches: %w[#1a2b3c #FFAA00], allow_any: false }.freeze

  def fieldtype(config = {}) = Nibble::Field.new("brand", { "type" => "color" }.merge(config.deep_stringify_keys)).fieldtype

  def errors(config, value)
    fields = Nibble::Fields.new([ { handle: "brand", field: { type: "color" }.merge(config) } ], source: "test")
    Nibble::Validator.new(fields).validate("brand" => value).errors["brand"]
  end

  def check_problems(field)
    path = @themes.join("check", "schema", "fieldsets", "brand.yml")
    FileUtils.mkdir_p(path.dirname)
    path.write({ "title" => "Brand", "fields" => [ { "handle" => "brand", "field" => { "type" => "color" }.merge(field.deep_stringify_keys) } ] }.to_yaml)
    config = Nibble::Config.new({ "theme" => "check", "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: @themes)
    Nibble::Check.run(config:, static: true).problems.map(&:message).grep(/field 'brand'/)
  end

  test "a colour is stored as lowercase #rrggbb, so a page can compare and print it as it is" do
    assert_equal "#ffaa00", fieldtype.process(" #FFAA00 ")
    assert_nil fieldtype.process("")
    assert_nil errors({}, "#FFAA00"), "a person who types capitals isn't refused for it"
  end

  test "anything but six hex digits is refused, so a theme never prints a value a stylesheet can't read" do
    [ "#fff", "ffaa00", "red", "#ffaa0080", "rgb(0,0,0)", "#gg0000" ].each do |value|
      assert_equal [ "The Brand field must be a colour written as #rrggbb, such as #1a2b3c." ], errors({}, value), value
    end
  end

  test "with allow_any off only a swatch is accepted, whatever its case" do
    assert_nil errors(SWATCHES, "#ffaa00")
    assert_equal [ "The selected Brand is invalid." ], errors(SWATCHES, "#000000")
    assert_nil errors({ swatches: %w[#1a2b3c] }, "#000000"), "swatches alone are suggestions"
  end

  test "check refuses swatches and defaults that could never be stored" do
    assert_equal [ "field 'brand' swatch \"red\" isn't a colour written as #rrggbb", "field 'brand' default \"#fff\" isn't a colour written as #rrggbb" ],
      check_problems(swatches: %w[#1a2b3c red], default: "#FFF")
    assert_equal [ "field 'brand' has allow_any: false but no swatches to choose from" ], check_problems(allow_any: false)
    assert_equal [ "field 'brand' default #000000 isn't one of its swatches" ], check_problems(**SWATCHES, default: "#000000")
    assert_empty check_problems(**SWATCHES, default: "#FFAA00")
  end

  test "an app is told the swatches when they are the only choice" do
    assert_equal %w[#1a2b3c #ffaa00], Nibble::Operations::FieldSchema.for(Nibble::Field.new("brand", { "type" => "color", **SWATCHES.deep_stringify_keys }))["enum"]
    assert_match Regexp.new(Nibble::Operations::FieldSchema.for(Nibble::Field.new("brand", { "type" => "color" }))["pattern"]), "#1A2b3c"
  end
end
