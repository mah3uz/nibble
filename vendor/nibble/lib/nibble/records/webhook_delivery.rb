module Nibble
  module Records
    class WebhookDelivery < ::ApplicationRecord
      self.table_name = "webhook_deliveries"

      STATUSES = %w[pending delivered failed].freeze

      def self.record_type = "webhook_delivery"
      def self.polymorphic_name = record_type

      belongs_to :webhook, class_name: "Nibble::Records::Webhook"
      has_many :outbound_requests, as: :owner, dependent: :delete_all

      validates :status, inclusion: { in: STATUSES }

      def record_type = self.class.record_type
    end
  end
end
