module Nibble
  module Outbound
    class Template
      PATTERN = /\{(secret|config|field|form|global)\.([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)?)\}/
      WHOLE = /\A#{PATTERN}\z/

      attr_reader :secrets_used

      def initialize(fields: {}, form: nil)
        @fields = fields.to_h.stringify_keys
        @form = form
        @secrets_used = []
      end

      def render(value)
        case value
        when Hash then value.transform_values { |item| render(item) }
        when Array then value.map { |item| render(item) }
        when String
          return lookup(*value.match(WHOLE).captures) if value.match?(WHOLE)

          value.gsub(PATTERN) { lookup(Regexp.last_match(1), Regexp.last_match(2)).to_s }
        else value
        end
      end

      private

      def lookup(kind, name)
        case kind
        when "field" then @fields[name]
        when "form" then name == "title" ? (@form&.title || @form&.handle) : nil
        when "global" then global(*name.split(".", 2))
        when "config" then Nibble.config.outbound_config.fetch(name) { raise Error, "{config.#{name}} isn't in outbound.config" }
        else secret(name)
        end
      end

      def global(handle, field)
        return nil if field.nil? || handle == Integrations::HANDLE || !Nibble.schema.find(:globals, handle)

        Dependencies.add("global:#{handle}")
        value = Records::GlobalSet.find_by(handle:, locale: Nibble.config.default_locale.code)&.values&.dig(field)
        value.is_a?(String) || value.is_a?(Numeric) ? value : nil
      end

      def secret(name)
        raise Error, "{secret.#{name}} isn't listed in outbound.secrets" unless Nibble.config.outbound_secrets.include?(name)

        value = ENV["NIBBLE_SECRET_#{name.upcase}"].presence || Rails.application.credentials.dig(:nibble, :secrets, name.to_sym).presence
        raise Error, "the secret #{name} isn't set (NIBBLE_SECRET_#{name.upcase} or credentials nibble.secrets.#{name})" unless value

        @secrets_used << value.to_s
        value
      end
    end
  end
end
