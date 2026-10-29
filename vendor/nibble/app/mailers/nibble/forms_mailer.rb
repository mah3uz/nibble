module Nibble
  class FormsMailer < Nibble::ApplicationMailer
    def submission(form_handle, index, data, plan)
      @form = Nibble::Forms.find(form_handle) or return
      notify = @form.notify[index] or return
      fields = @form.fields.all.values
      fields = fields.select { |field| notify["fields"].include?(field.handle) } if notify["fields"]
      @rows = fields.map { |field| [ field.display(plan.locale), Array(Nibble::Forms.display_value(field, data[field.handle], plan.locale)).join(", ") ] }
      @message = plan.message
      @visitor = plan.visitor
      @locale = plan.locale
      @link = plan.link unless plan.visitor
      reply_to = data[notify["reply_to"]] if notify["reply_to"]
      @reply_to = reply_to if reply_to.to_s.match?(URI::MailTo::EMAIL_REGEXP)

      mail to: plan.to, cc: plan.cc.presence, bcc: plan.bcc.presence,
           subject: plan.subject || "New submission: #{@form.title(plan.locale) || @form.handle}", reply_to: @reply_to
    end

    def resume(form_handle, to, link, expires_at, locale)
      @form = Nibble::Forms.find(form_handle) or return
      @title = @form.title(locale) || @form.handle
      @link = link
      @expires_at = expires_at
      mail to:, subject: "Finish filling in #{@title}"
    end
  end
end
