module Nibble
  module Jobs
    class CheckReleases < Nibble::ApplicationJob
      queue_as :maintenance

      def perform = Releases.refresh!
    end
  end
end
