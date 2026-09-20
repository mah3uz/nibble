# Nightly complete database backup. Runs via config/recurring.yml.
class DatabaseSnapshotJob < ApplicationJob
  queue_as :maintenance

  def perform
    DatabaseSnapshot.create!
  end
end
