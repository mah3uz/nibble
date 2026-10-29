require "test_helper"

class ReferenceDocsTest < ActiveSupport::TestCase
  DOCS = Rails.root.join("vendor/nibble/docs/reference")

  def assert_documented(text, needle, message = nil) = assert(text.include?(needle), message || "expected the page to contain #{needle}")

  def page(name) = DOCS.join("#{name}.md").read

  def section(text, handle)
    text[/^### `#{Regexp.escape(handle)}`\n(.*?)(?=^##+ |\z)/m, 1] or flunk "fieldtypes.md has no section for `#{handle}`"
  end

  test "every fieldtype has a section naming each of its options" do
    text = page("fieldtypes")

    Nibble::Fieldtypes.all.each do |fieldtype|
      body = section(text, fieldtype.handle)
      fieldtype.config_fields.handles.each do |option|
        assert_documented body, "`#{option}`", "the #{fieldtype.handle} section doesn't document its `#{option}` option"
      end
    end
  end

  test "every fieldtype says whether a public form can use it" do
    text = page("fieldtypes")

    Nibble::Fieldtypes.all.each do |fieldtype|
      expected = Nibble::Forms::PUBLIC_FIELDTYPES.include?(fieldtype.handle) ? "**Public forms:** yes" : "**Public forms:** no"
      assert_documented section(text, fieldtype.handle), expected, "#{fieldtype.handle} is documented with the wrong public form answer"
    end
  end

  test "every option all fields take is documented" do
    text = page("fieldtypes")

    Nibble::Field::COMMON_OPTIONS.each_key do |option|
      assert_documented text, "`#{option}`", "fieldtypes.md doesn't document the common option `#{option}`"
    end
  end

  test "every validation rule is documented with its message key" do
    text = page("validation")

    Nibble::Validation::BUILT_IN.each do |rule|
      assert_documented text, "| `#{rule}` |", "validation.md has no row for the `#{rule}` rule"
    end
    Nibble::Validation::MESSAGES.each_key do |key|
      assert_documented text, "`#{key.split('.').first}`", "validation.md doesn't mention the message key `#{key}`"
    end
  end

  test "every condition key, operator and alias is documented" do
    text = page("conditions")

    (Nibble::Conditions::KEYS + Nibble::Conditions::OPERATORS + Nibble::Conditions::ALIASES.keys).each do |name|
      assert_documented text, "`#{name}`", "conditions.md doesn't document `#{name}`"
    end
  end

  test "the section page links to each reference page" do
    index = page("index")

    %w[fieldtypes validation conditions].each { |name| assert_documented index, "(#{name}.md)" }
  end
end
