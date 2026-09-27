module Nibble
  class OauthToken < Nibble::ApplicationRecord
    self.table_name = "nibble_oauth_tokens"

    KINDS = %w[access refresh ci].freeze
    PREFIXES = { "access" => "nibble_at_", "refresh" => "nibble_rt_", "ci" => "nibble_ci_" }.freeze
    ACCESS_LIFETIME = 1.hour
    REFRESH_IDLE = 30.days
    # Two requests refreshing at once both present the same token; only a later reuse means it was copied.
    REUSE_GRACE = 10.seconds

    belongs_to :grant, class_name: "Nibble::Grant"

    validates :kind, inclusion: { in: KINDS }

    def self.digest(plaintext) = Digest::SHA256.hexdigest(plaintext.to_s)

    def self.issue(grant, kind, resource:, expires_at: nil)
      plaintext = "#{PREFIXES.fetch(kind)}#{SecureRandom.base58(43)}"
      expires_at ||= { "access" => ACCESS_LIFETIME.from_now, "refresh" => REFRESH_IDLE.from_now }.fetch(kind)
      create!(grant:, kind:, resource:, token_digest: digest(plaintext), expires_at: [ expires_at, grant.expires_at ].min,
        created_at: Time.current)
      plaintext
    end

    def self.find_by_token(plaintext, kinds:)
      return nil if plaintext.blank?

      where(kind: kinds).find_by(token_digest: digest(plaintext))
    end

    def usable? = revoked_at.nil? && expires_at.future? && grant.active?

    def reused? = used_at.present? && used_at < REUSE_GRACE.ago
  end
end
