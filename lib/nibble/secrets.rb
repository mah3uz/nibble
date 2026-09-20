module Nibble
  module Secrets
    PURPOSE = :nibble_secret

    module_function

    def encrypt(plain) = encryptor.encrypt_and_sign(plain.to_s, purpose: PURPOSE)

    def decrypt(ciphertext)
      ciphertext.presence && encryptor.decrypt_and_verify(ciphertext, purpose: PURPOSE)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    def global(handle, field, locale: Nibble.config.default_locale.code)
      decrypt(Records::GlobalSet.find_by(handle:, locale:)&.data&.dig(field.to_s))
    end

    def encryptor
      @encryptor ||= ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key("nibble/secrets", 32))
    end
  end
end
