require "test_helper"

class DatabaseSnapshotJobTest < ActiveJob::TestCase
  test "delegates to DatabaseSnapshot" do
    called = false
    original = DatabaseSnapshot.method(:create!)
    DatabaseSnapshot.define_singleton_method(:create!) { called = true }

    DatabaseSnapshotJob.perform_now

    assert called
  ensure
    DatabaseSnapshot.define_singleton_method(:create!, original)
  end
end
