module Nibble
  # A change an app asked to make that goes live or can't be quietly undone, waiting for the person it acts for.
  class Approval < Nibble::ApplicationRecord
    self.table_name = "nibble_approvals"

    LIFETIME = 1.day
    STATUSES = %w[pending approved denied used].freeze

    belongs_to :grant, class_name: "Nibble::Grant"

    validates :status, inclusion: { in: STATUSES }

    before_validation(on: :create) do
      self.public_id ||= "appr_#{SecureRandom.base58(24)}"
      self.expires_at ||= LIFETIME.from_now
    end

    def self.digest(operation, input) = Digest::SHA256.hexdigest([ operation, input.to_h.except("approval", "idempotency_key").sort.to_h ].to_json)

    def expired? = expires_at.past?

    def open? = status == "pending" && !expired?

    def usable_for?(grant, operation, input)
      status == "approved" && !expired? && grant_id == grant.id && self.operation == operation && digest == self.class.digest(operation, input)
    end
  end
end
