require "test_helper"

class RecurringScheduleTest < ActiveSupport::TestCase
  SCHEDULE = YAML.safe_load(ERB.new(Rails.root.join("config/recurring.yml").read).result, aliases: true)["production"]
  QUEUES = %w[events deliveries media search maintenance].freeze

  test "every scheduled job exists, so a typo can't silently stop a nightly task" do
    SCHEDULE.each_value do |task|
      next unless task["class"]

      assert task["class"].safe_constantize, "#{task['class']} doesn't exist"
    end
  end

  test "scheduled entries go live and trash is emptied, because nothing else runs those jobs" do
    classes = SCHEDULE.values.filter_map { |task| task["class"] }

    assert_includes classes, "Nibble::Jobs::RunSchedule"
    assert_includes classes, "Nibble::Jobs::PurgeTrash"
  end

  test "every job runs on one of the engine's named queues" do
    jobs = [ DatabaseSnapshotJob, *Nibble::Jobs.constants.map { |name| Nibble::Jobs.const_get(name) }.select { |klass| klass < ApplicationJob } ]

    jobs.each { |job| assert_includes QUEUES, job.queue_name, "#{job} is on '#{job.queue_name}'" }
    SCHEDULE.each_value { |task| assert_includes QUEUES, task["queue"], task.inspect if task["queue"] }
  end
end
