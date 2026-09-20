module Nibble
  module Forms
    module Captcha
      VERIFY_URLS = {
        "turnstile" => "https://challenges.cloudflare.com/turnstile/v0/siteverify",
        "recaptcha" => "https://www.google.com/recaptcha/api/siteverify"
      }.freeze
      TOKEN_PARAMS = %w[_captcha cf-turnstile-response g-recaptcha-response].freeze
      DEFAULT_MIN_SCORE = 0.5

      module_function

      def token(params) = TOKEN_PARAMS.lazy.map { |name| params[name].presence }.find(&:itself)

      def verify(settings, token, ip:)
        return false if token.blank? || settings["secret_key"].blank?

        response = Outbound.request(:post, VERIFY_URLS.fetch(settings["provider"]), purpose: "captcha", format: :form,
          body: { secret: settings["secret_key"], response: token, remoteip: ip }.compact, secrets: [ settings["secret_key"] ], timeout: 5)
        result = response.json.to_h
        return false unless result["success"] == true

        settings["provider"] != "recaptcha" || result["score"].to_f >= settings.fetch("min_score", DEFAULT_MIN_SCORE).to_f
      rescue Outbound::Refused, Outbound::Failed
        false
      end
    end
  end
end
