require "test_helper"

# VACUUM INTO can't run inside a transaction, so this suite can't use Rails' normal
# transactional-fixture rollback; any record created here must be cleaned up explicitly.
class DatabaseSnapshotTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @env = ENV.to_h.slice("DB_SNAPSHOT_BUCKET", "DB_SNAPSHOT_REGION")
    ENV["DB_SNAPSHOT_BUCKET"] = "test-backups"
    ENV["DB_SNAPSHOT_REGION"] = "ap-southeast-2"
    @put_calls = []
    DatabaseSnapshot.s3_client = Aws::S3::Client.new(region: "ap-southeast-2", stub_responses: true)
    DatabaseSnapshot.s3_client.stub_responses(:put_object, ->(context) {
      @put_calls << context.params.except(:body).merge(body: context.params[:body].read)
      {}
    })
    # An isolated directory per test — parallel workers otherwise race on the same real
    # storage/backups path and the same date-based filename.
    DatabaseSnapshot.local_dir = Pathname(Dir.mktmpdir)
  end

  teardown do
    %w[DB_SNAPSHOT_BUCKET DB_SNAPSHOT_REGION].each { |key| @env.key?(key) ? ENV[key] = @env[key] : ENV.delete(key) }
    DatabaseSnapshot.s3_client = nil
    FileUtils.rm_rf(DatabaseSnapshot.local_dir)
    DatabaseSnapshot.local_dir = nil
    Nibble::Records::Entry.where(slug: "database-snapshot-test").delete_all
  end

  test "raises a clear error instead of silently skipping when unconfigured" do
    ENV.delete("DB_SNAPSHOT_BUCKET")
    assert_raises(RuntimeError) { DatabaseSnapshot.create! }
  end

  test "keeps a local gzipped copy and uploads the identical content to S3" do
    local_path = DatabaseSnapshot.create!
    date = Time.current.strftime("%Y-%m-%d")

    assert_equal DatabaseSnapshot.local_dir.join("#{date}.sqlite3.gz"), local_path
    assert File.exist?(local_path)
    assert_not File.exist?(DatabaseSnapshot.local_dir.join("#{date}.sqlite3")), "the uncompressed intermediate file should be cleaned up"

    call = @put_calls.sole
    assert_equal "test-backups", call[:bucket]
    assert_equal "cms_db_snapshots/test/#{date}.sqlite3.gz", call[:key]
    assert_equal File.binread(local_path), call[:body]
  end

  test "the backup restores to a database with the current data" do
    Nibble::Records::Entry.create!(collection: "posts", blueprint: "post", locale: "en", slug: "database-snapshot-test", title: "Snapshot Test")
    local_path = DatabaseSnapshot.create!

    restored_path = Pathname(Dir.mktmpdir).join("restore.sqlite3")
    File.binwrite(restored_path, Zlib::GzipReader.new(File.open(local_path, "rb")).read)
    db = SQLite3::Database.new(restored_path.to_s)

    assert_equal [ [ "Snapshot Test" ] ], db.execute("SELECT title FROM entries WHERE slug = 'database-snapshot-test'")
  ensure
    db&.close
    File.delete(restored_path) if restored_path && File.exist?(restored_path)
  end

  test "prunes local copies older than 7 days but doesn't touch S3" do
    old_path = DatabaseSnapshot.local_dir.join("2000-01-01.sqlite3.gz")
    File.write(old_path, "old")
    File.utime(8.days.ago.to_time, 8.days.ago.to_time, old_path)

    DatabaseSnapshot.create!

    assert_not File.exist?(old_path)
    assert_equal 1, @put_calls.size
  end
end
