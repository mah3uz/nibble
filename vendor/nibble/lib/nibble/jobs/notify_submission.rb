module Nibble
  module Jobs
    class NotifySubmission < Nibble::ApplicationJob
      queue_as :deliveries

      def perform(form_handle, submission_id: nil, data: nil)
        form = Forms.find(form_handle) or return
        submission = submission_id && Records::FormSubmission.find_by(id: submission_id)
        return if submission_id && submission.nil?

        data = submission&.data || data
        form.notify.each_index { |index| Nibble::FormsMailer.submission(form.handle, index, data).deliver_later }
        return unless form.cp_notify?

        Nibble::User.all.select { |user| Access.can?(user, "forms.#{form.handle}.view") }.each do |user|
          Records::Notification.notify(user.id, "form.submitted", subject: submission, title: form.title || form.handle, form: form.handle)
        end
      end
    end
  end
end
