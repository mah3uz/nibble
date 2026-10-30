module Nibble
  module Jobs
    class PurgeNavigation < Nibble::ApplicationJob
      queue_as :events

      # A page rendered just before the date can be written to the cache just after it, so the purge waits a little past it.
      GRACE = 5.seconds

      def self.schedule(tree, now: Time.current)
        tree.show_dates.select { |time| time > now }.each { |time| set(wait_until: time + GRACE).perform_later(tree.id) }
      end

      def perform(tree_id)
        tree = Records::NavigationTree.find_by(id: tree_id) or return
        PageCache.purge("navigation:#{tree.handle}")
      end
    end
  end
end
