module Nibble
  module Integrations
    HANDLE = "integrations".freeze

    module_function

    def settings = Records::GlobalSet.find_by(handle: HANDLE, locale: Nibble.config.default_locale.code)&.data.to_h

    def captcha
      values = settings
      provider = values["captcha_provider"].presence
      return nil unless Forms::CAPTCHA_PROVIDERS.include?(provider) && values["captcha_site_key"].present?

      { "provider" => provider, "site_key" => values["captcha_site_key"], "secret_key" => Secrets.decrypt(values["captcha_secret_key"]),
        "min_score" => (values["recaptcha_min_score"].presence || Forms::Captcha::DEFAULT_MIN_SCORE).to_f }
    end

    def mail_from
      values = settings
      address = values["mail_from_address"].presence || "noreply@#{Nibble.url_options[:host] || 'localhost'}"
      name = values["mail_from_name"].presence
      name ? ActionMailer::Base.email_address_with_name(address, name) : address
    end

    def head_html(values) = place_html(values, :head)
    def body_start_html(values) = place_html(values, :body_start)
    def body_html(values) = place_html(values, :body_end)

    def place_html(values, place)
      snippets = Array(values["custom_code"]).filter_map do |row|
        row = row.to_h.stringify_keys
        row["code"] if row["enabled"] != false && row["placement"] == place.to_s && row["code"].present?
      end
      (Analytics.render(values["analytics"]).tags.fetch(place) + snippets).join("\n").html_safe
    end
  end
end
