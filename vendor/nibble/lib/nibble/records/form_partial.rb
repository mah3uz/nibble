module Nibble
  module Records
    class FormPartial < Nibble::ApplicationRecord
      self.table_name = "form_partials"

      TOKEN = /\A[A-Za-z0-9_-]{43}\z/

      validates :form, :token_digest, :expires_at, presence: true

      scope :live, -> { where(expires_at: Time.current..) }
      scope :expired, -> { where(expires_at: ...Time.current) }

      def self.digest(token) = Digest::SHA256.hexdigest(token)

      def self.find_live(form, token)
        live.find_by(form:, token_digest: digest(token)) if token.is_a?(String) && token.match?(TOKEN)
      end

      def self.keep!(form:, values:, encrypt:, days:, locale:)
        token = SecureRandom.urlsafe_base64(32)
        partial = new(form:, token_digest: digest(token), locale:, expires_at: days.days.from_now)
        secret = values.slice(*encrypt).compact
        partial.data = values.except(*secret.keys)
        partial.encrypted_data = secret.to_h { |handle, value| [ handle, Secrets.encrypt(value.to_json, purpose: partial.purpose(handle)) ] }.presence
        partial.save!
        [ partial, token ]
      end

      def data
        stored = super
        return stored if encrypted_data.blank?

        stored.merge(encrypted_data.to_h { |handle, ciphertext| [ handle, reveal(handle, ciphertext) ] })
      end

      def status = "saved"

      def purpose(handle) = "nibble/form_partial:#{token_digest}:#{handle}"

      private

      def reveal(handle, ciphertext)
        plain = Secrets.decrypt(ciphertext, purpose: purpose(handle))
        plain && JSON.parse(plain)
      end
    end
  end
end
