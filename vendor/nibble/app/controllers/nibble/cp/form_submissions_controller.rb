module Nibble
  module Cp
    class FormSubmissionsController < BaseController
      before_action :find_submission
      before_action { authorize!("forms.#{@form.handle}.view") }

      def show
        @submission.update_column(:read_at, Time.current) unless @submission.read?
        fields = @form.fields.add_values(@submission.data)
        meta = with_stored_labels(fields.meta.merge(file_meta))
        render inertia: "cp/forms/Submission", props: {
          form: { handle: @form.handle, title: @form.title || @form.handle.humanize },
          submission: { id: @submission.id, status: @submission.status, created_at: @submission.created_at.utc.iso8601,
                        handled: @submission.handled?, handled_at: @submission.handled_at&.utc&.iso8601,
                        handled_by: handler_name, notes: @submission.notes.includes(:user).map { |note| note_row(note) },
                        deliveries: @submission.deliveries.map { |delivery| delivery_row(delivery) }, values_kept: @submission.data.present? },
          spam_days: spam_days,
          can_edit: can_edit?,
          can_resend_notifications: @form.notify.any? && @submission.status != "spam" && can_edit?,
          can_mark_not_spam: @submission.status == "spam" && can_edit?,
          blueprint: { handle: @form.handle, title: @form.title, tabs: [ { handle: "main", display: "Main",
                                                                          sections: [ { fields: fields.to_publish_a } ] } ] },
          values: fields.pre_process.values,
          meta:,
          can_delete: Nibble::Access.can?(Nibble::Current.user, "forms.#{@form.handle}.delete")
        }
      end

      def handled
        authorize!("forms.#{@form.handle}.edit")
        if ActiveModel::Type::Boolean.new.cast(params[:handled])
          @submission.update!(handled_at: Time.current, handled_by_id: Nibble::Current.user.id)
        else
          @submission.update!(handled_at: nil, handled_by_id: nil)
        end
        redirect_to submission_path, notice: @submission.handled? ? "Marked as handled." : "Marked as new."
      end

      def unread
        authorize!("forms.#{@form.handle}.edit")
        @submission.update_column(:read_at, nil)
        redirect_to "/cp/forms/#{@form.handle}", notice: "Marked as unread."
      end

      def add_note
        authorize!("forms.#{@form.handle}.edit")
        note = @submission.notes.build(body: params[:body].to_s.strip, user: Nibble::Current.user)
        if note.save
          Nibble::Forms::Audit.record("form.note_added", user: Nibble::Current.user, ip: request.remote_ip, subject: @submission,
            form: @form.handle, note_id: note.id)
          redirect_to submission_path, notice: "Note added."
        else
          redirect_to submission_path, alert: "The note can't be added: #{note.errors.full_messages.to_sentence}."
        end
      end

      def destroy
        authorize!("forms.#{@form.handle}.delete")
        @submission.destroy!
        Nibble::Forms::Audit.record("form.submission_deleted", user: Nibble::Current.user, ip: request.remote_ip, form: @form.handle, count: 1)
        redirect_to "/cp/forms/#{@form.handle}", notice: "Submission deleted."
      end

      def not_spam
        authorize!("forms.#{@form.handle}.edit")
        result = Nibble::Forms::Submit.not_spam(@form, @submission, user: Nibble::Current.user, ip: request.remote_ip)
        path = "/cp/forms/#{@form.handle}/submissions/#{@submission.id}"
        case result.status
        when :ok then redirect_to path, notice: "Marked as not spam and sent on."
        when :rejected then redirect_to path, alert: "Marked as not spam, but a delivery rejected it."
        when :invalid then redirect_to path, alert: "It can't be marked as not spam: #{result.errors.values.flatten.join(' ')}"
        when :cleared then redirect_to path, alert: "Its values are no longer kept, so it can't be marked as not spam."
        else redirect_to path, notice: "This submission is no longer marked as spam."
        end
      end

      def retry
        authorize!("forms.#{@form.handle}.edit")
        delivery = @submission.delivery(params[:key]) or raise ActiveRecord::RecordNotFound
        raise ActionController::BadRequest, "only failed deliveries can be retried" unless delivery["status"] == "failed"

        Nibble::Forms::Deliver.retry!(@submission, params[:key])
        redirect_back_or_to "/cp/forms/#{@form.handle}/submissions/#{@submission.id}", notice: "Delivery queued to retry."
      end

      def resend_notifications
        authorize!("forms.#{@form.handle}.edit")
        path = "/cp/forms/#{@form.handle}/submissions/#{@submission.id}"
        return redirect_to path, alert: "This submission has no notifications to send." if @form.notify.empty? || @submission.status == "spam" || @submission.data.blank?

        Nibble::Records::AuditEntry.create!(action: "form.notifications_resent", actor_type: "user", actor_id: Nibble::Current.user.id, subject_type: @submission.record_type,
          subject_id: @submission.id, changeset: { "form" => @form.handle }, ip: request.remote_ip, created_at: Time.current)
        Nibble::Jobs::NotifySubmission.perform_later(@form.handle, submission_id: @submission.id, resend: true)
        redirect_to path, notice: "Notifications queued to send again."
      end

      private

      def find_submission
        @form = Nibble::Forms.find(params[:handle]) or raise ActiveRecord::RecordNotFound
        @submission = Nibble::Records::FormSubmission.where(form: @form.handle).find(params[:id])
      end

      def can_edit? = Nibble::Access.can?(Nibble::Current.user, "forms.#{@form.handle}.edit")

      def submission_path = "/cp/forms/#{@form.handle}/submissions/#{@submission.id}"

      def handler_name = @submission.handled_by_id && Nibble::User.find_by(id: @submission.handled_by_id)&.name

      def note_row(note) = { id: note.id, body: note.body, author: note.user&.name, created_at: note.created_at.utc.iso8601 }

      def spam_days = [ @form.spam_retention_days, @form.retention_days ].filter_map { |days| days.to_i if days.to_i.positive? }.min

      def file_meta
        @form.fields.all.values.select { |field| field.type == "files" }.to_h do |field|
          [ field.handle, { "files" => Array(@submission.data[field.handle]).map { |file| file_row(file) } } ]
        end
      end

      def with_stored_labels(meta)
        @submission.labels.each do |handle, kept|
          options = meta.dig(handle, "options") or next
          known = options.map { |option| option["value"].to_s }
          meta[handle] = meta[handle].merge("options" => options + kept.except(*known).map { |value, label| { "value" => value, "label" => label } })
        end
        meta
      end

      def file_row(file)
        { "filename" => file["filename"], "size" => file["size"],
          "url" => "/cp/forms/#{@form.handle}/submissions/#{@submission.id}/files/#{file['id']}" }
      end

      def delivery_errors(errors)
        return unless errors.is_a?(Hash)

        errors.transform_keys { |handle| @form.fields.all[handle]&.display || handle.to_s.humanize }
      end

      def delivery_row(delivery)
        delivery.slice("key", "target", "mode", "status", "attempts", "response_status", "error", "errors", "at")
          .merge("errors" => delivery_errors(delivery["errors"]), "can_retry" => delivery["key"].to_s.start_with?("api.") && delivery["status"] == "failed" && Nibble::Access.can?(Nibble::Current.user, "forms.#{@form.handle}.edit"))
      end
    end
  end
end
