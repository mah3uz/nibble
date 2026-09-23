module Nibble
  module Fieldtypes
    class Secret < Fieldtype
      MASK = "••••••••".freeze

      self.categories = %w[special]
      self.contract_samples = [ "stored-ciphertext", nil ]
      self.keywords = %w[password key token credential api]
      self.config_field_items = [
        { "display" => "Appearance", "fields" => { "placeholder" => { "type" => "text" } } }
      ]

      def pre_process(stored) = stored.present? ? { "set" => true, "ciphertext" => stored } : nil

      def process(value)
        return value.presence if value.is_a?(String)
        return nil unless value.is_a?(Hash)

        value = value.stringify_keys
        return Secrets.encrypt(value["plain"]) if value["plain"].present?

        value["clear"] ? nil : value["ciphertext"].presence
      end

      def pre_process_validatable(value) = value.is_a?(Hash) && (value["plain"].present? || value["ciphertext"].present?) ? MASK : nil
      def pre_process_index(value) = value.present? ? MASK : nil
      def augment(_value) = nil
      def ts_type = "null"
    end
  end
end
