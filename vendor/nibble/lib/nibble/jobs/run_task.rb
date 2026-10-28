module Nibble
  module Jobs
    class RunTask < Nibble::ApplicationJob
      queue_as :maintenance

      def perform(run_id)
        run = Records::ScheduledTaskRun.find_by(id: run_id) or return

        Tasks.perform(run)
      end
    end
  end
end
