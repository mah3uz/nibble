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

    def head_html(values)
      parts = []
      if (id = values["gtm_container_id"].presence)
        parts << %(<script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer',#{id.to_json});</script>)
      end
      if (id = values["ga4_measurement_id"].presence)
        parts << %(<script async src="https://www.googletagmanager.com/gtag/js?id=#{ERB::Util.url_encode(id)}"></script>)
        parts << %(<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config',#{id.to_json});</script>)
      end
      if (src = values["analytics_script_src"].presence)
        attributes = Array(values["analytics_script_attributes"]).filter_map do |row|
          %( #{row['name']}="#{ERB::Util.html_escape(row['value'])}") if row["name"].to_s.match?(/\Adata-[a-z0-9-]+\z/)
        end
        parts << %(<script defer src="#{ERB::Util.html_escape(src)}"#{attributes.join}></script>)
      end
      parts << values["head_code"] if values["head_code"].present?
      parts.join("\n").html_safe
    end

    def body_html(values)
      parts = []
      if (id = values["gtm_container_id"].presence)
        parts << %(<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=#{ERB::Util.url_encode(id)}" height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>)
      end
      parts << values["body_code"] if values["body_code"].present?
      parts.join("\n").html_safe
    end
  end
end
