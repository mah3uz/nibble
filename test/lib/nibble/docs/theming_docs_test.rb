require "test_helper"

class ThemingDocsTest < ActiveSupport::TestCase
  RUNTIME = Nibble.core_root.join("frontend/nibble")

  def documented = Nibble.core_root.join("docs/theming").glob("*.md").map(&:read).join("\n")

  def exports
    index = RUNTIME.join("index.ts").read
    values = index.scan(/^export \{([^}]+)\}/).flatten.flat_map { |list| list.split(",") }.map { |name| name.split(/\s+as\s+/).last.strip }
    types = RUNTIME.join("types.ts").read.scan(/^export type (\w+)/).flatten
    values + types
  end

  test "the theming guides name every export of @nibble, because a theme can import any of them" do
    assert_operator exports.size, :>, 20
    text = documented
    missing = exports.reject { |name| text.match?(/`#{name}[`(]/) }

    assert_empty missing, "document these @nibble exports under docs/theming: #{missing.join(', ')}"
  end
end
