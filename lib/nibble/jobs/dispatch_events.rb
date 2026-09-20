module Nibble
  module Jobs
    class DispatchEvents < ::ApplicationJob
      queue_as :events

      def perform = Events.dispatch_pending
    end
  end
end
