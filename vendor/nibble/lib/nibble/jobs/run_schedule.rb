module Nibble
  module Jobs
    class RunSchedule < Nibble::ApplicationJob
      queue_as :maintenance

      def perform(now: Time.current)
        Records::Entry.kept.where(status: "scheduled", published_at: ..now).find_each { |entry| Lifecycle.call(entry, :go_live) }
        Records::Entry.live.where(unpublish_at: ..now).find_each { |entry| Lifecycle.call(entry, :expire) }
      end
    end
  end
end
