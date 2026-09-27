module Nibble
  class DeviceCode < Nibble::ApplicationRecord
    self.table_name = "nibble_device_codes"

    LIFETIME = 10.minutes
    INTERVAL = 5
    # No vowels or look-alike letters, so a code can't spell a word or be misread: 20^8 codes.
    ALPHABET = "BCDFGHJKLMNPQRSTVWXZ".chars.freeze

    belongs_to :oauth_client, class_name: "Nibble::OauthClient"
    belongs_to :grant, class_name: "Nibble::Grant", optional: true

    scope :pending, -> { where(status: "pending").where("expires_at > ?", Time.current) }

    def self.issue(oauth_client:, resource:, ip:)
      device_code = SecureRandom.base58(43)
      record = create!(oauth_client:, resource:, requested_ip: ip, device_code_digest: OauthToken.digest(device_code),
        user_code: Array.new(8) { ALPHABET.sample(random: SecureRandom) }.join, expires_at: LIFETIME.from_now,
        created_at: Time.current)
      [ record, device_code ]
    end

    def self.normalize(user_code) = user_code.to_s.upcase.gsub(/[^A-Z]/, "")

    def self.find_by_device_code(plaintext) = plaintext.present? ? find_by(device_code_digest: OauthToken.digest(plaintext)) : nil

    def display_code = user_code.scan(/.{4}/).join("-")

    def expired? = expires_at.past?
  end
end
