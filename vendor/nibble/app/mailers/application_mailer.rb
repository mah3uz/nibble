class ApplicationMailer < ActionMailer::Base
  default from: -> { Nibble::Integrations.mail_from }
  layout "mailer"
  helper_method :site_name

  private

  def site_name
    @site_name ||= Nibble::Records::GlobalSet.find_by(handle: "site")&.values&.dig("name").presence || "the site"
  end
end
