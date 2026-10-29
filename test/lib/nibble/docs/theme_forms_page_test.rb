require "test_helper"

class ThemeFormsPageTest < ActiveSupport::TestCase
  PAGE = Nibble::Engine.root.join("docs/theming/forms.md").read
  HOOK = Nibble::Engine.root.join("frontend/nibble/useNibbleForm.ts").read

  CONFIG = {
    "text" => { "placeholder" => "p", "input_type" => "email", "character_limit" => 50, "default" => "d", "width" => 50, "prepend" => "$", "append" => "x", "autocomplete" => "email" },
    "textarea" => { "rows" => 3 },
    "integer" => { "min" => 1, "max" => 9, "step" => 2 },
    "decimal" => { "decimals" => 2 },
    "range" => { "min" => 0, "max" => 10, "step" => 1 },
    "rating" => { "max" => 5 },
    "toggle" => { "inline_label" => "I accept the [terms](/terms)" },
    "select" => { "multiple" => true, "max_items" => 2, "clearable" => true, "options" => { "a" => "A" } },
    "radio" => { "inline" => true, "options" => { "a" => "A" } },
    "checkboxes" => { "options" => { "a" => "A" } },
    "button_group" => { "options" => { "a" => "A" } },
    "date" => { "time_enabled" => true, "earliest_date" => "2026-01-01", "latest_date" => "2030-01-01", "time_zone" => "Australia/Sydney" },
    "time" => { "seconds" => true, "earliest" => "09:00", "latest" => "17:00" },
    "color" => { "swatches" => [ "#ff0000" ], "allow_any" => true },
    "files" => { "max_files" => 2, "max_file_size" => 5, "extensions" => [ "pdf" ] },
    "calculation" => { "formula" => "1" },
    "note" => { "text" => "A *note*" }
  }.freeze

  def definition
    fields = CONFIG.map do |type, config|
      { "handle" => type, "field" => config.merge("type" => type, "display" => type.titleize, "if" => { "text" => "a" }, "required" => { "if" => { "text" => "b" } }) }
    end
    fields << { "handle" => "tracked", "field" => { "type" => "text", "hidden" => true, "value" => "web", "prefill" => { "query" => "utm_source" } } }
    item = Nibble::Schema::Item.new(kind: :forms, handle: "docs_probe", parent: nil, path: "docs_probe.yml", layer: :site,
      data: { "title" => "Probe", "steps" => true, "resume" => true, "resume_email" => "text", "spam" => { "captcha" => true, "min_seconds" => 3 },
              "limits" => { "closes_at" => "2000-01-01T00:00" }, "sections" => [ { "display" => "One", "fields" => fields } ] })
    Nibble::Forms::Definition.call(Nibble::Forms::Form.new(item:))
  end

  def missing(names) = names.uniq.reject { |name| PAGE.match?(/`#{name}[`(]/) }

  test "the page names every key of the form definition" do
    assert_empty missing(definition.keys + definition["messages"].keys)
  end

  test "the page names every key a field can send" do
    keys = definition["fields"].flat_map(&:keys)

    assert_equal Nibble::Forms::PUBLIC_FIELDTYPES.sort, CONFIG.keys.sort
    assert_empty Nibble::Forms::Definition::FIELD_CONFIG - keys, "add the new setting to CONFIG"

    %w[inline_label_html conditions text_html time_zone hidden options].each { |key| assert_includes keys, key }
    assert_empty missing(keys)
  end

  test "the page names every member useNibbleForm returns" do
    members = HOOK[/^  return \{\n(.*?)^  \}\n\}/m, 1].scan(/^    (\w+)/).flatten

    assert_operator members.size, :>, 30
    assert_empty missing(members)
  end
end
