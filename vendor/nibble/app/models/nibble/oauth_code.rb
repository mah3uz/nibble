module Nibble
  class OauthCode < Nibble::ApplicationRecord
    self.table_name = "nibble_oauth_codes"

    LIFETIME = 1.minute

    belongs_to :grant, class_name: "Nibble::Grant"

    def self.issue(grant:, redirect_uri:, code_challenge:, resource:)
      plaintext = SecureRandom.base58(43)
      create!(grant:, redirect_uri:, code_challenge:, resource:, code_digest: OauthToken.digest(plaintext),
        expires_at: LIFETIME.from_now, created_at: Time.current)
      plaintext
    end

    def self.find_by_code(plaintext) = plaintext.present? ? find_by(code_digest: OauthToken.digest(plaintext)) : nil

    def expired? = expires_at.past?

    def verifies?(verifier)
      return false unless verifier.to_s.match?(/\A[A-Za-z0-9\-._~]{43,128}\z/)

      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      ActiveSupport::SecurityUtils.secure_compare(challenge, code_challenge)
    end
  end
end
