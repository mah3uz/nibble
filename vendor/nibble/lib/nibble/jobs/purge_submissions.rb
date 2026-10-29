module Nibble
  module Jobs
    class PurgeSubmissions < Nibble::ApplicationJob
      queue_as :maintenance

      def perform
        Forms.all.each do |form|
          spam_days = form.spam_retention_days.to_i
          Records::FormSubmission.where(form: form.handle, status: "spam", created_at: ...spam_days.days.ago).delete_all if spam_days.positive?

          days = form.retention_days.to_i
          next unless days.positive?

          Records::FormSubmission.where(form: form.handle).where(created_at: ...days.days.ago).find_each(&:destroy!)
        end
      end
    end
  end
end
