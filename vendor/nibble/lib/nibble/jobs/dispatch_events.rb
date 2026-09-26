module Nibble
  module Jobs
    class DispatchEvents < Nibble::ApplicationJob
      queue_as :events

      def perform = Events.dispatch_pending
    end
  end
end
