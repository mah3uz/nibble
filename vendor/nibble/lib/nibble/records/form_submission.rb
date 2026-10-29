module Nibble
  module Records
    class FormSubmission < Nibble::ApplicationRecord
      self.table_name = "form_submissions"

      STATUSES = %w[received delivered rejected failed spam].freeze

      def self.record_type = "form_submission"
      def self.polymorphic_name = record_type
      def self.receive!(values, encrypt: [], **attributes)
        transaction do
          create!(data: values.except(*encrypt), **attributes).tap { |record| record.keep!(values, encrypt:) if values.slice(*encrypt).compact.any? }
        end
      end

      def self.hash_ip(ip) = ip.presence && OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, ip)[0, 32]

      has_many_attached :files
      has_many :outbound_requests, as: :owner, dependent: :delete_all
      has_many :unique_keys, class_name: "Nibble::Records::FormSubmissionKey", dependent: :delete_all
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

      def data
        stored = super
        return stored if encrypted_data.blank?

        stored.merge(encrypted_data.to_h { |handle, ciphertext| [ handle, reveal(handle, ciphertext) ] })
      end

      def keep!(values, encrypt: [], **attributes)
        secret = values.slice(*encrypt).compact
        sealed = secret.to_h { |handle, value| [ handle, Secrets.encrypt(value.to_json, purpose: purpose(handle)) ] }
        update!(data: values.except(*secret.keys), encrypted_data: sealed.presence, **attributes)
      end

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

      def purpose(handle) = "nibble/form_submission:#{id}:#{handle}"

      def reveal(handle, ciphertext)
        plain = Secrets.decrypt(ciphertext, purpose: purpose(handle))
        plain && JSON.parse(plain)
      end

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
