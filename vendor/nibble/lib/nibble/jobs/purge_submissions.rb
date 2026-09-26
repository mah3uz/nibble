module Nibble
  module Jobs
    class PurgeSubmissions < Nibble::ApplicationJob
      queue_as :maintenance

      def perform
        Forms.all.each do |form|
          days = form.retention_days.to_i
          next unless days.positive?

          Records::FormSubmission.where(form: form.handle).where(created_at: ...days.days.ago).find_each(&:destroy!)
        end
      end
    end
  end
end
