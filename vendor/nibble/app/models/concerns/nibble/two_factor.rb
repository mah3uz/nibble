module Nibble
  module TwoFactor
    extend ActiveSupport::Concern

    RECOVERY_CODE_COUNT = 8
    DRIFT = 30

    def two_factor? = totp? || passkeys?

    def passkeys? = user_credentials.any?

    def totp? = totp_confirmed_at.present?

    def requires_two_factor? = roles.any?(&:require_2fa?)

    def totp_secret = Nibble::Secrets.decrypt(totp_secret_ciphertext)

    def start_totp_setup!
      secret = ROTP::Base32.random
      update!(totp_secret_ciphertext: Nibble::Secrets.encrypt(secret), totp_confirmed_at: nil, totp_last_used_at: nil)
      secret
    end

    def totp_provisioning_uri
      secret = totp_secret or return nil
      ROTP::TOTP.new(secret, issuer: Nibble::TwoFactor.issuer).provisioning_uri(email_address)
    end

    def confirm_totp(code)
      return false unless totp_secret && verify_totp(code)

      update!(totp_confirmed_at: Time.current)
    end

    def verify_totp(code)
      secret = totp_secret or return false
      at = ROTP::TOTP.new(secret).verify(code.to_s.strip, drift_behind: DRIFT, after: totp_last_used_at)
      return false unless at

      update!(totp_last_used_at: Time.at(at))
    end

    def disable_two_factor!
      update!(totp_secret_ciphertext: nil, totp_confirmed_at: nil, totp_last_used_at: nil, recovery_codes: [])
    end

    def generate_recovery_codes!
      codes = Array.new(RECOVERY_CODE_COUNT) { SecureRandom.alphanumeric(10).downcase }
      update!(recovery_codes: codes.map { |code| Nibble::TwoFactor.digest(code) })
      codes
    end

    def consume_recovery_code(code)
      digest = Nibble::TwoFactor.digest(code.to_s.strip.downcase.delete("^a-z0-9"))
      return false unless recovery_codes.include?(digest)

      update!(recovery_codes: recovery_codes - [ digest ])
    end

    def self.digest(code) = Digest::SHA256.hexdigest(code)

    def self.issuer = URI.parse(Nibble.config.url.to_s).host.presence || "Nibble"
  end
end
