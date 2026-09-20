module Nibble
  module Lockout
    ATTEMPTS = 10
    # A second factor is mistyped far more often than a password, so it gets its own, longer rope.
    CODE_ATTEMPTS = 20
    WINDOW = 15.minutes

    module_function

    def failures(email, kind: nil)
      scope = scope(email).where(created_at: WINDOW.ago..)
      kind ? scope.where(kind:).count : scope.count
    end

    def locked?(email)
      failures(email, kind: "password") >= ATTEMPTS || failures(email, kind: "code") >= CODE_ATTEMPTS
    end

    def record_failure(email, kind: "password", ip: nil)
      Records::SignInAttempt.create!(email_digest: digest(email), kind:, ip:, created_at: Time.current)
      Records::SignInAttempt.where(created_at: ...WINDOW.ago).delete_all
      failures(email, kind:)
    end

    def clear(email) = scope(email).delete_all

    def scope(email) = Records::SignInAttempt.where(email_digest: digest(email))

    def digest(email) = Digest::SHA256.hexdigest(email.to_s.strip.downcase)
  end
end
