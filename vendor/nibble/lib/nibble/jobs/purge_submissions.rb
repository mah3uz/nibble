module Nibble
  module Jobs
    class PurgeSubmissions < Nibble::ApplicationJob
      queue_as :maintenance

      REMOVED_FORM_DAYS = 30

      def perform
        Forms.all.each do |form|
          purge(form.handle, retention_days: form.retention_days, spam_days: form.spam_retention_days)
          Records::FormRetention.find_or_initialize_by(form: form.handle)
            .update!(retention_days: form.retention_days.to_i.positive? ? form.retention_days.to_i : nil,
              spam_retention_days: form.spam_retention_days.to_i.positive? ? form.spam_retention_days.to_i : nil, missing_since: nil)
        end
        purge_removed_forms
        Records::FormPartial.expired.delete_all
      end

      private

      def purge(handle, retention_days:, spam_days:)
        spam_days = spam_days.to_i
        Records::FormSubmission.where(form: handle, status: "spam", created_at: ...spam_days.days.ago).delete_all if spam_days.positive?

        days = retention_days.to_i
        return unless days.positive?

        Records::FormSubmission.where(form: handle).where(created_at: ...days.days.ago).find_each(&:destroy!)
      end

      def purge_removed_forms
        removed = Records::FormSubmission.distinct.pluck(:form) - Forms.all.map(&:handle)
        removed.each do |handle|
          retention = Records::FormRetention.find_or_initialize_by(form: handle)
          retention.update!(missing_since: Time.current) if retention.missing_since.nil?
          purge(handle, retention_days: retention.retention_days, spam_days: retention.spam_retention_days)
          next if retention.retention_days || retention.missing_since > REMOVED_FORM_DAYS.days.ago

          Records::FormSubmission.where(form: handle).find_each(&:destroy!)
        end
        Records::FormRetention.where.not(missing_since: nil).where.not(form: removed).where.not(form: Forms.all.map(&:handle)).delete_all
      end
    end
  end
end
