require "test_helper"

class CliWordsTest < ActiveSupport::TestCase
  CLI_WORDS = %w[new auth remote mcp skill doctor help completion].freeze

  # `nibble <word>` runs a local task unless the word is the CLI's own, so a task named after one could never be reached.
  test "no nibble task starts with a word the nibble CLI keeps for itself" do
    first_words = Nibble.core_root.glob("lib/commands/**/*_command.rb").flat_map do |path|
      source = path.read
      namespace = source[/namespace "nibble:([a-z_]+)/, 1]
      namespace ? [ namespace ] : source.scan(/^  desc "([a-z_]+)/).flatten
    end

    assert_includes first_words, "check", "the task list was read"
    assert_empty first_words & CLI_WORDS
  end
end
