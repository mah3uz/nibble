module Nibble
  module Jobs
    class CheckReleases < ::ApplicationJob
      queue_as :maintenance

      def perform = Releases.refresh!
    end
  end
end
