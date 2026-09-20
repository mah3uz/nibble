class ApplicationMailer < ActionMailer::Base
  default from: -> { Nibble::Integrations.mail_from }
  layout "mailer"
end
