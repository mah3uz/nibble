module Nibble
  module Records
    class FormSubmission < Nibble::ApplicationRecord
      self.table_name = "form_submissions"

      STATUSES = %w[received delivered rejected failed spam].freeze

      def self.record_type = "form_submission"
      def self.polymorphic_name = record_type
      def self.hash_ip(ip) = ip.presence && OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, ip)[0, 32]

      has_many_attached :files
      has_many :outbound_requests, as: :owner, dependent: :delete_all
      has_many :notes, -> { order(:created_at, :id) }, class_name: "Nibble::Records::FormSubmissionNote", dependent: :delete_all

      validates :form, presence: true
      validates :status, inclusion: { in: STATUSES }

      scope :kept, -> { where.not(status: "spam") }
      scope :unread, -> { where(read_at: nil) }
      scope :handled, -> { where.not(handled_at: nil) }
      scope :unhandled, -> { where(handled_at: nil) }

      def record_type = self.class.record_type
      def definition = Forms.find(form)
      def read? = read_at.present?
      def handled? = handled_at.present?

      def delivery(key) = deliveries.find { |item| item["key"] == key }

      def update_delivery!(key, **changes)
        changes = changes.transform_keys(&:to_s)
        list = deliveries.map { |item| item["key"] == key ? item.merge(changes) : item }
        update!(deliveries: list, status: overall_status(list))
      end

      def record_delivery!(key, **changes)
        with_lock do
          changes = changes.transform_keys(&:to_s)
          previous = delivery(key).to_h
          entry = previous.merge(changes, "key" => key, "attempts" => previous["attempts"].to_i + 1)
          update!(deliveries: deliveries.reject { |item| item["key"] == key } + [ entry ])
        end
      end

      private

      def overall_status(list)
        list = list.select { |item| item["key"].to_s.start_with?("api.") }
        return status if status == "spam" || list.empty?
        return "rejected" if list.any? { |item| item["status"] == "rejected" }
        return "failed" if list.any? { |item| item["status"] == "failed" }

        list.all? { |item| item["status"] == "delivered" } ? "delivered" : "received"
      end
    end
  end
end
