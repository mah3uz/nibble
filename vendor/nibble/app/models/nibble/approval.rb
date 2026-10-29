module Nibble
  # A change an app asked to make that goes live or can't be quietly undone, waiting for the person it acts for.
  class Approval < Nibble::ApplicationRecord
    self.table_name = "nibble_approvals"

    LIFETIME = 1.day
    STATUSES = %w[pending approved done failed denied].freeze
    STANDING = %w[pending approved done].freeze

    belongs_to :grant, class_name: "Nibble::Grant"

    validates :status, inclusion: { in: STATUSES }

    before_validation(on: :create) do
      self.public_id ||= "appr_#{SecureRandom.base58(24)}"
      self.expires_at ||= LIFETIME.from_now
    end

    def self.digest(operation, input) = Digest::SHA256.hexdigest([ operation, input.to_h.except("approval", "idempotency_key").sort.to_h ].to_json)

    def expired? = expires_at.past?

    def open? = status == "pending" && !expired?

    def state = status == "pending" && expired? ? "expired" : status

    def for?(operation, input) = self.operation == operation && digest == self.class.digest(operation, input)

    def summary
      { "approval" => public_id, "status" => state, "operation" => operation, "result" => result, "error" => error,
        "expires_at" => expires_at.utc.iso8601 }
    end
  end
end
