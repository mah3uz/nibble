require "test_helper"

class OperatorDocsTest < ActiveSupport::TestCase
  DOCS = Nibble.core_root.join("docs/running")
  ENV_READ = /ENV(?:\[|\.fetch\()\s*["']([A-Z][A-Z0-9_]*)["']/
  ENV_DIRS = %w[app lib templates bin config].freeze
  GENERATED = %w[collection taxonomy blueprint fieldset global navigation form plugin].freeze

  test "every nibble task is in the commands guide" do
    commands = Nibble.core_root.glob("lib/commands/**/*_command.rb").flat_map do |path|
      source = path.read
      namespace = source[/namespace "(nibble:[a-z_]+)"/, 1] || "nibble"
      source.scan(/^\s*desc "([a-z_]+)[^"]*",\s*"[^"]*"(, hide: true)?/).reject(&:last).map { |(name, _)| "#{namespace}:#{name}" }
    end
    commands += GENERATED.map { |kind| "nibble:generate:#{kind}" }

    assert_includes commands, "nibble:check", "the task list was read"
    guide = DOCS.join("commands.md").read
    assert_empty commands.uniq.reject { |name| guide.include?(name) }, "tasks missing from running/commands.md"
  end

  test "every environment variable Nibble reads is in the configuration guide" do
    names = ENV_DIRS.flat_map { |dir| Nibble.core_root.join(dir).glob("**/*").select(&:file?) }
      .flat_map { |path| path.read.scan(ENV_READ).flatten }.uniq

    assert_includes names, "SITE_URL", "the variables were read"
    guide = DOCS.join("configuration.md").read
    assert_empty names.reject { |name| guide.include?("`#{name}`") }, "variables missing from running/configuration.md"
  end
end
