module Nibble
  module Outbound
    class Template
      PATTERN = /\{(secret|config|field)\.([A-Za-z0-9_]+)\}/
      WHOLE = /\A#{PATTERN}\z/

      attr_reader :secrets_used

      def initialize(fields: {})
        @fields = fields.to_h.stringify_keys
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
        when "config" then Nibble.config.outbound_config.fetch(name) { raise Error, "{config.#{name}} isn't in outbound.config" }
        else secret(name)
        end
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
