require "test_helper"

class Nibble::Forms::CalculationsCheckTest < ActiveSupport::TestCase
  setup { @themes = Pathname(Dir.mktmpdir("nibble-themes")) }
  teardown { FileUtils.rm_rf(@themes) }

  def theme_file(relative, content)
    path = @themes.join("check", "schema", relative)
    FileUtils.mkdir_p(path.dirname)
    path.write(content.deep_stringify_keys.to_yaml)
  end

  def problems
    config = Nibble::Config.new({ "theme" => "check", "locales" => [ { "code" => "en", "default" => true } ] }, themes_path: @themes)
    Nibble::Check.run(config:, static: true).problems.map { |problem| problem.to_s.sub(%r{\A.*/check/schema/}, "") }
  end

  def calculation(formula, **extra) = { type: "calculation", formula:, **extra }

  test "a quote built from numbers, toggles, numeric choices and other calculations passes" do
    theme_file("fieldsets/pricing.yml", title: "Pricing", fields: [ { handle: "tax", field: calculation("{subtotal} * 0.1", decimals: 2) } ])
    theme_file("forms/quote.yml", title: "Quote", fields: [
      { handle: "quantity", field: { type: "integer" } },
      { handle: "unit_price", field: { type: "integer", hidden: true, value: 400 } },
      { handle: "size", field: { type: "select", options: { 10 => "Small", "2.5" => "Tiny" } } },
      { handle: "express", field: { type: "toggle" } },
      { handle: "subtotal", field: calculation("{quantity} * {unit_price} * {size} + {express} * 20") },
      { import: "pricing" },
      { handle: "total", field: calculation("round({subtotal} + {tax}, 2)", decimals: 2, prepend: "$") }
    ])

    assert_empty problems.grep(/quote\.yml|pricing\.yml/)
  end

  test "check refuses a formula the server couldn't calculate, so a broken total never reaches a visitor" do
    theme_file("forms/broken.yml", title: "Broken", fields: [
      { handle: "name", field: { type: "text" } },
      { handle: "extras", field: { type: "select", multiple: true, options: { 1 => "One" } } },
      { handle: "plan", field: { type: "radio", options: { basic: "Basic" } } },
      { handle: "unparsed", field: calculation("{name} +") },
      { handle: "unknown", field: calculation("{missing} * 2") },
      { handle: "texty", field: calculation("{name} + {extras} + {plan}") },
      { handle: "blank", field: { type: "calculation", decimals: 1.5, required: true } },
      { handle: "shown", field: { type: "text", if: { texty: "> 3" } } }
    ])

    found = problems.grep(/broken\.yml/).map { |problem| problem.delete_prefix("forms/broken.yml: ") }
    [
      "field 'unparsed' has a formula that doesn't parse: the formula ends too soon",
      "field 'unknown' has a formula naming {missing}, which isn't one of the form's fields",
      "field 'texty' has a formula naming {name}, a text field that doesn't hold a number",
      "field 'texty' has a formula naming {extras}, a select field that doesn't hold a number",
      "field 'texty' has a formula naming {plan}, a radio field that doesn't hold a number",
      "field 'blank' is a calculation, which can't be required",
      "field 'blank' decimals must be a whole number from 0 to 15",
      "field 'blank' needs a `formula`",
      "field 'shown' has a condition on 'texty', a calculation, which a condition can't read"
    ].each { |message| assert_includes found, message }
  end

  test "check refuses calculations that depend on each other in a loop, which could never settle" do
    theme_file("forms/loop.yml", title: "Loop", fields: [
      { handle: "a", field: calculation("{b} + 1") },
      { handle: "b", field: calculation("{c} * 2") },
      { handle: "c", field: calculation("{a} - 1") },
      { handle: "d", field: calculation("{d}") },
      { handle: "e", field: calculation("{a} + 1") }
    ])

    found = problems.grep(/loop\.yml/)
    assert_includes found, "forms/loop.yml: field 'a' is calculated from itself, through a → b → c → a"
    assert_includes found, "forms/loop.yml: field 'd' is calculated from itself, through d → d"
    assert_empty found.grep(/field 'e'/)
  end

  test "a calculation belongs to a form only: entries and globals have nothing to calculate it at" do
    theme_file("collections/posts.yml", title: "Posts", route: "/posts/{slug}", blueprints: [ "post" ])
    theme_file("blueprints/collections/posts/post.yml", title: "Post", tabs: { main: { sections: [ { fields: [
      { handle: "title", field: { type: "text" } },
      { handle: "total", field: calculation("1 + 1") }
    ] } ] } })

    assert_includes problems, "blueprints/collections/posts/post.yml: field 'total' is a calculation, which only a form can have"
  end
end
