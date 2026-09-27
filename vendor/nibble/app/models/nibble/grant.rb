module Nibble
  # What a person let an app do on their behalf. It can only narrow what their roles already allow.
  class Grant < Nibble::ApplicationRecord
    self.table_name = "nibble_grants"

    KINDS = %w[app ci].freeze
    PRESETS = %w[read draft everything custom].freeze
    LIFETIME = 90.days
    TOUCH_EVERY = 1.minute

    belongs_to :user, class_name: "Nibble::User"
    belongs_to :oauth_client, class_name: "Nibble::OauthClient", optional: true
    has_many :tokens, class_name: "Nibble::OauthToken", dependent: :delete_all
    has_many :codes, class_name: "Nibble::OauthCode", dependent: :delete_all
    has_many :approvals, class_name: "Nibble::Approval", dependent: :delete_all

    validates :kind, inclusion: { in: KINDS }
    validates :preset, inclusion: { in: PRESETS }
    validates :name, presence: true, length: { maximum: 100 }
    validate :abilities_are_grantable

    scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

    before_validation { self.expires_at ||= LIFETIME.from_now }

    def active? = revoked_at.nil? && expires_at.future?

    def covers?(ability) = Access.matches?(abilities, ability.to_s)

    def revoke!
      transaction do
        update!(revoked_at: Time.current) if revoked_at.nil?
        tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
      end
    end

    def used!(ip)
      return if last_used_at && last_used_at > TOUCH_EVERY.ago

      update_columns(last_used_at: Time.current, last_used_ip: ip)
    end

    private

    def abilities_are_grantable
      refused = Array(abilities).reject { |ability| AgentAccess.grantable?(ability) }
      errors.add(:abilities, "can't include #{refused.to_sentence}") if refused.any?
    end
  end
end
