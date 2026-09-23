module Nibble
  module Records
    class FormSubmission < ::ApplicationRecord
      self.table_name = "form_submissions"

      STATUSES = %w[received delivered rejected failed spam].freeze

      def self.record_type = "form_submission"
      def self.polymorphic_name = record_type
      def self.hash_ip(ip) = ip.presence && OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, ip)[0, 32]

      has_many_attached :files
      has_many :outbound_requests, as: :owner, dependent: :delete_all

      validates :form, presence: true
      validates :status, inclusion: { in: STATUSES }

      scope :kept, -> { where.not(status: "spam") }
      scope :unread, -> { where(read_at: nil) }

      def record_type = self.class.record_type
      def definition = Forms.find(form)
      def read? = read_at.present?

      def delivery(key) = deliveries.find { |item| item["key"] == key }

      def update_delivery!(key, **changes)
        changes = changes.transform_keys(&:to_s)
        list = deliveries.map { |item| item["key"] == key ? item.merge(changes) : item }
        update!(deliveries: list, status: overall_status(list))
      end

      private

      def overall_status(list)
        return status if status == "spam" || list.empty?
        return "rejected" if list.any? { |item| item["status"] == "rejected" }
        return "failed" if list.any? { |item| item["status"] == "failed" }

        list.all? { |item| item["status"] == "delivered" } ? "delivered" : "received"
      end
    end
  end
end
