require "test_helper"

# Invariant (CLAUDE.md): no SQLite-specific SQL outside a short list of intentionally isolated
# files, so a future move to another database is a one-off script plus reimplementing each of them
# (Search wraps FTS5; DatabaseSnapshot wraps VACUUM INTO — a Postgres port would use pg_dump there
# instead, same as it'd use Postgres full-text search in place of Search).
class DatabasePortabilityTest < ActiveSupport::TestCase
  SQLITE_ONLY = Regexp.union(
    /\b(?:fts5|json_extract|json_each|sqlite_master)\b/i,
    /\b(?:MATCH\s+['"?]|PRAGMA\s|VACUUM\b|AUTOINCREMENT\b|GLOB\s)/ # upper-case SQL keywords, not prose
  )
  ALLOWED = [
    "app/models/search.rb",
    "lib/nibble/search.rb",
    "app/services/database_snapshot.rb",
    "lib/nibble/db/migrate/20260920102900_create_search_index.rb",
    "lib/nibble/db/migrate/20260920103000_create_search_index_trigram.rb"
  ].freeze

  test "SQLite-specific SQL appears only in the allowed files" do
    offenders = Dir.glob(Rails.root.join("{app,lib}/**/*.rb")).filter_map do |file|
      relative = Pathname(file).relative_path_from(Rails.root).to_s
      next if ALLOWED.include?(relative)

      relative if File.read(file).match?(SQLITE_ONLY)
    end
    assert_empty offenders, "SQLite-specific SQL found outside #{ALLOWED.join(', ')}: #{offenders.join(', ')}"
  end
end
