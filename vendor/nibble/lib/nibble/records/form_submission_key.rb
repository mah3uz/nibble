module Nibble
  module Records
    class FormSubmissionKey < Nibble::ApplicationRecord
      self.table_name = "form_submission_keys"

      EMAIL_LIKE = /\A[^@\s]+@[^@\s]+\z/

      belongs_to :form_submission, class_name: "Nibble::Records::FormSubmission"

      def self.for(form, field, value)
        text = value.to_s.strip
        text = text.downcase if text.match?(EMAIL_LIKE)
        { form:, field:, digest: OpenSSL::HMAC.hexdigest("SHA256", secret, [ form, field, text ].to_json) }
      end

      def self.secret = @secret ||= Rails.application.key_generator.generate_key("nibble/form_submission_keys", 32)
    end
  end
end
