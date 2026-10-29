module Nibble
  module Records
    class FormSubmissionNote < Nibble::ApplicationRecord
      self.table_name = "form_submission_notes"

      belongs_to :form_submission, class_name: "Nibble::Records::FormSubmission"
      belongs_to :user, class_name: "Nibble::User", optional: true

      validates :body, presence: true, length: { maximum: 5000 }
    end
  end
end
