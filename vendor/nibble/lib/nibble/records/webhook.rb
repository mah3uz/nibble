module Nibble
  module Records
    class Webhook < Nibble::ApplicationRecord
      self.table_name = "webhooks"

      has_many :deliveries, class_name: "Nibble::Records::WebhookDelivery", dependent: :destroy

      validates :name, presence: { message: "Give the webhook a name" }
      validate :url_is_http
      validate :events_are_known
      validate :collections_exist

      scope :enabled, -> { where(enabled: true) }

      def self.generate_secret = "whsec_#{SecureRandom.hex(24)}"

      def secret = Secrets.decrypt(secret_ciphertext)
      def secret=(plain)
        self.secret_ciphertext = Secrets.encrypt(plain)
      end

      def subscribed?(name, payload)
        return false unless events.any? { |pattern| pattern.end_with?(".*") ? name.start_with?(pattern.delete_suffix("*")) : pattern == name }

        collections.empty? || collections.include?(payload["collection"])
      end

      private

      def url_is_http
        uri = URI.parse(url.to_s)
        errors.add(:url, "Enter an absolute http or https URL") unless %w[http https].include?(uri.scheme) && uri.host.present?
      rescue URI::InvalidURIError
        errors.add(:url, "Enter an absolute http or https URL")
      end

      def events_are_known
        errors.add(:events, "Choose at least one event") if events.blank?
        unknown = Array(events) - Webhooks::EVENTS.keys
        errors.add(:events, "#{unknown.join(', ')} isn't an event") if unknown.any?
      end

      def collections_exist
        unknown = Array(collections) - Nibble.schema.collections.map(&:handle)
        errors.add(:collections, "#{unknown.join(', ')} isn't a collection") if unknown.any?
      end
    end
  end
end
