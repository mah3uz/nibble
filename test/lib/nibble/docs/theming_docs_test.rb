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

  test "every docs page has its own id, since the docs site addresses pages by it" do
    ids = Nibble.core_root.join("docs").glob("**/*.md").map { |file| file.read[/\A---\nid: (\S+)/, 1] }

    assert_equal ids.uniq, ids
    assert_not_includes ids, nil
  end
end
