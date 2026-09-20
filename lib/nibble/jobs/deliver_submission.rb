module Nibble
  module Jobs
    class DeliverSubmission < ::ApplicationJob
      queue_as :deliveries

      def perform(form_handle, index, submission_id: nil, data: nil, attempt: 1)
        form = Forms.find(form_handle) or return
        submission = submission_id && Records::FormSubmission.find_by(id: submission_id)
        return if submission_id && (submission.nil? || submission.status == "spam")

        outcome = Forms::Deliver.call(form, index, submission&.data || data, submission:)
        return unless outcome.status == "failed"

        policy = Forms::Deliver.retry_policy(form, index)
        return if attempt >= policy["attempts"]

        self.class.set(wait: (policy["backoff_seconds"] * (2**(attempt - 1))).seconds)
          .perform_later(form_handle, index, submission_id:, data:, attempt: attempt + 1)
      end
    end
  end
end
