module Nibble
  module Jobs
    class HandleSubmission < Nibble::ApplicationJob
      queue_as :deliveries

      def perform(form_handle, submission_id: nil, data: nil)
        form = Forms.find(form_handle) or return
        handler = Forms.handlers.fetch(form.handler)
        submission = submission_id && Records::FormSubmission.find_by(id: submission_id)
        return if submission_id && submission.nil?

        handler.call(form:, data: submission&.data || data, submission:)
      end
    end
  end
end
