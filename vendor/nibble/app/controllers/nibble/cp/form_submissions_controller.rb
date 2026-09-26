module Nibble
  module Cp
    class FormSubmissionsController < BaseController
      before_action :find_submission
      before_action { authorize!("forms.#{@form.handle}.view") }

      def show
        @submission.update_column(:read_at, Time.current) unless @submission.read?
        fields = @form.fields.add_values(@submission.data)
        meta = fields.meta.merge(file_meta)
        render inertia: "cp/forms/Submission", props: {
          form: { handle: @form.handle, title: @form.title || @form.handle.humanize },
          submission: { id: @submission.id, status: @submission.status, created_at: @submission.created_at.utc.iso8601,
                        deliveries: @submission.deliveries.map { |delivery| delivery_row(delivery) } },
          blueprint: { handle: @form.handle, title: @form.title, tabs: [ { handle: "main", display: "Main",
                                                                          sections: [ { fields: fields.to_publish_a } ] } ] },
          values: fields.pre_process.values,
          meta:,
          can_delete: Nibble::Access.can?(Nibble::Current.user, "forms.#{@form.handle}.delete")
        }
      end

      def destroy
        authorize!("forms.#{@form.handle}.delete")
        @submission.destroy!
        redirect_to "/cp/forms/#{@form.handle}", notice: "Submission deleted."
      end

      def retry
        authorize!("forms.#{@form.handle}.edit")
        delivery = @submission.delivery(params[:key]) or raise ActiveRecord::RecordNotFound
        raise ActionController::BadRequest, "only failed deliveries can be retried" unless delivery["status"] == "failed"

        Nibble::Forms::Deliver.retry!(@submission, params[:key])
        redirect_back_or_to "/cp/forms/#{@form.handle}/submissions/#{@submission.id}", notice: "Delivery queued to retry."
      end

      private

      def find_submission
        @form = Nibble::Forms.find(params[:handle]) or raise ActiveRecord::RecordNotFound
        @submission = Nibble::Records::FormSubmission.where(form: @form.handle).find(params[:id])
      end

      def file_meta
        @form.fields.all.values.select { |field| field.type == "files" }.to_h do |field|
          [ field.handle, { "files" => Array(@submission.data[field.handle]).map { |file| file_row(file) } } ]
        end
      end

      def file_row(file)
        { "filename" => file["filename"], "size" => file["size"],
          "url" => "/cp/forms/#{@form.handle}/submissions/#{@submission.id}/files/#{file['id']}" }
      end

      def delivery_row(delivery)
        delivery.slice("key", "target", "mode", "status", "attempts", "response_status", "error", "errors", "at")
          .merge("can_retry" => delivery["status"] == "failed" && Nibble::Access.can?(Nibble::Current.user, "forms.#{@form.handle}.edit"))
      end
    end
  end
end
