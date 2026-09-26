module Nibble
  class ApplicationMailer < ActionMailer::Base
    default from: -> { Nibble::Integrations.mail_from }
    layout "nibble/mailer"
    helper_method :site_name

    # Links point at the site Nibble serves, whatever host the app's own mailers are given.
    def default_url_options = Nibble.url_options

    private

    def site_name
      @site_name ||= Nibble::Records::GlobalSet.find_by(handle: "site")&.values&.dig("name").presence || "the site"
    end
  end
end
