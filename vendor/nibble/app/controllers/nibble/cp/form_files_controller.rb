module Nibble
  module Cp
    class FormFilesController < BaseController
      include ActiveStorage::SetCurrent

      LINK_EXPIRY = 5.minutes

      before_action { authorize!("forms.#{params[:handle]}.view") }

      def show
        submission = Nibble::Records::FormSubmission.where(form: params[:handle]).find(params[:submission_id])
        blob = submission.files.blobs.find(params[:id])
        redirect_to blob.url(expires_in: LINK_EXPIRY, disposition: :attachment), allow_other_host: true
      end
    end
  end
end
