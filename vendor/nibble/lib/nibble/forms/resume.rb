module Nibble
  module Forms
    class Resume < Submit
      TOKEN_FIELD = "_nibble_resume".freeze
      QUERY = "resume".freeze
      MAX_BYTES = 64.kilobytes

      Loaded = Data.define(:params, :definition, :result)

      def self.call(form, params, page:, **options) = new(form, params, page:, **options).call

      def self.load(form, params, locale: nil)
        params = params.to_h.stringify_keys
        return Loaded.new(params:, definition: nil, result: nil) unless form.resume?

        definition = { "email" => form.resume_email, "days" => form.resume_days, "token" => nil }
        token = params[QUERY].presence or return Loaded.new(params:, definition:, result: nil)

        Dependencies.add(Dependencies::UNCACHEABLE)
        partial = Records::FormPartial.find_live(form.handle, token)
        unless partial
          return Loaded.new(params:, definition:, result: { "handle" => form.handle, "status" => "expired", "message" => Forms.message("resume.expired", locale) })
        end

        values = partial.data
        prefilled = form.fields.all.values.to_h { |field| [ Definition.prefill_name(field), values[field.handle] ] }.except(nil)
        Loaded.new(params: prefilled.select { |_, value| value.is_a?(String) }.merge(params.except(QUERY)), definition: definition.merge("token" => token),
          result: { "handle" => form.handle, "status" => "resumed", "values" => values })
      end

      def self.complete(form, token) = Records::FormPartial.find_live(form.handle, token)&.destroy!

      def initialize(form, params, page:, **options)
        super(form, params, **options)
        @page = page
      end

      def process
        return closed if @form.closed?
        return result(:ok) if spam?
        return result(:invalid, errors: { "base" => [ captcha_message ] }) unless captcha_passed?

        email = @params[@form.resume_email]
        unless email.is_a?(String) && email.strip.match?(URI::MailTo::EMAIL_REGEXP)
          return result(:invalid, errors: { @form.resume_email => [ Forms.message("resume.email", @locale) ] })
        end

        values = kept_values
        return result(:invalid, errors: { "base" => [ Forms.message("resume.too_large", @locale) ] }) if values.to_json.bytesize > MAX_BYTES

        partial, token = Records::FormPartial.keep!(form: @form.handle, values:, encrypt: @form.encrypted_handles, days: @form.resume_days, locale: @locale)
        begin
          Nibble::FormsMailer.resume(@form.handle, email.strip, link(token), partial.expires_at, @locale).deliver_now
        rescue StandardError => error
          Rails.logger.error("Form '#{@form.handle}' couldn't send a resume link: #{error.message}")
          partial.destroy!
          return result(:invalid, errors: { "base" => [ Forms.message("resume.failed", @locale) ] })
        end
        self.class.complete(@form, @params[TOKEN_FIELD])
        result(:ok, values: { "token" => token })
      end

      private

      def kept_values
        fields = @form.fields
        files = fields.all.values.select { |field| field.type == "files" }.map(&:handle)
        @params.slice(*fields.handles).except(*files).select { |_, value| plain?(value) }.merge(hidden_values(fields))
      end

      def link(token) = "#{Nibble.config.url.to_s.chomp('/')}#{@page}?#{{ QUERY => token }.to_query}"

      def rate_key(kind) = super("resume.#{kind}")
    end
  end
end
