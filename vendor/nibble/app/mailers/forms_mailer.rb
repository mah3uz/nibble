class FormsMailer < ApplicationMailer
  def submission(form_handle, index, data)
    @form = Nibble::Forms.find(form_handle) or return
    notify = @form.notify[index] or return
    fields = @form.fields.all.values
    fields = fields.select { |field| notify["fields"].include?(field.handle) } if notify["fields"]
    @rows = fields.map { |field| [ field.display, Array(Nibble::Forms.display_value(field, data[field.handle])).join(", ") ] }
    reply_to = data[notify["reply_to"]] if notify["reply_to"]
    @reply_to = reply_to if reply_to.to_s.match?(URI::MailTo::EMAIL_REGEXP)

    mail to: notify["to"], subject: notify["subject"].presence || "New submission: #{@form.title || @form.handle}",
         reply_to: @reply_to
  end
end
