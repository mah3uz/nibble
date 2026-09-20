class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Reset your password", to: user.email_address
  end

  def invite(user)
    @user = user
    mail subject: "You've been invited to #{site_name}", to: user.email_address
  end

  private

  def site_name
    @site_name ||= Nibble::Records::GlobalSet.find_by(handle: "site")&.values&.dig("name").presence || "the site"
  end
  helper_method :site_name
end
