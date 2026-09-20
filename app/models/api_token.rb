class ApiToken < ApplicationRecord
  PREFIX = "nib".freeze
  SCOPES = %w[read preview health].freeze

  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true
  validate :scopes_are_known

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.issue(name:, scopes:, expires_at: nil, created_by: nil)
    plaintext = "#{PREFIX}_#{SecureRandom.hex(24)}"
    token = create!(name:, scopes:, expires_at:, created_by:, prefix: plaintext.first(11),
      token_digest: digest(plaintext))
    [ token, plaintext ]
  end

  def self.authenticate(plaintext)
    return nil if plaintext.blank?

    active.find_by(token_digest: digest(plaintext))
  end

  def self.digest(plaintext) = Digest::SHA256.hexdigest(plaintext.to_s)

  def active? = revoked_at.nil? && (expires_at.nil? || expires_at.future?)

  def allows?(scope)
    return false unless active?

    scopes.include?(scope.to_s) || (scope.to_s == "read" && scopes.include?("preview"))
  end

  def manages?(collection) = active? && scopes.include?("manage:#{collection}")

  private

  def scopes_are_known
    unknown = Array(scopes).reject { |scope| SCOPES.include?(scope) || manage_scope?(scope) }
    errors.add(:scopes, "can't include #{unknown.to_sentence}") if unknown.any?
  end

  def manage_scope?(scope)
    handle = scope.to_s.delete_prefix("manage:")
    scope.to_s.start_with?("manage:") && Nibble.schema.collections.any? { |item| item.handle == handle }
  end
end
