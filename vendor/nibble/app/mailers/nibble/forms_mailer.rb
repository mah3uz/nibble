module Nibble
  class FormsMailer < Nibble::ApplicationMailer
    helper_method :mail_text, :mail_html

    def submission(form_handle, index, data, plan)
      @form = Nibble::Forms.find(form_handle) or return
      notify = @form.notify[index] or return
      fields = @form.fields.all.values.reject(&:display_only?)
      fields = fields.select { |field| notify["fields"].include?(field.handle) } if notify["fields"]
      @rows = fields.map { |field| [ field.display(plan.locale), Array(Nibble::Forms.display_value(field, data[field.handle], plan.locale)).join(", ") ] }
      @message = plan.message
      @visitor = plan.visitor
      @locale = plan.locale
      @mail_locale = plan.locale
      @link = plan.link unless plan.visitor
      reply_to = data[notify["reply_to"]] if notify["reply_to"]
      @reply_to = reply_to if reply_to.to_s.match?(URI::MailTo::EMAIL_REGEXP)

      mail to: plan.to, cc: plan.cc.presence, bcc: plan.bcc.presence,
           subject: plan.subject || mail_text("submission.subject", title: @form.title(plan.locale) || @form.handle), reply_to: @reply_to
    end

    def resume(form_handle, to, link, expires_at, locale)
      @form = Nibble::Forms.find(form_handle) or return
      @title = @form.title(locale) || @form.handle
      @mail_locale = locale
      @link = link
      @expires_at = expires_at
      mail to:, subject: mail_text("resume.heading", title: @title)
    end

    private

    def mail_text(key, **values) = Nibble::Forms.message("mail.#{key}", @mail_locale, **values)

    def mail_html(key, **values)
      escaped = values.transform_values { |value| ERB::Util.html_escape(value) }
      mail_text(key, **escaped).html_safe
    end
  end
end
