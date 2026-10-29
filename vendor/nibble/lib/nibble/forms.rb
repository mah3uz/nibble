module Nibble
  module Forms
    PUBLIC_FIELDTYPES = %w[text textarea integer decimal range rating toggle select radio checkboxes date files calculation note time color button_group].freeze
    CAPTCHA_PROVIDERS = %w[turnstile recaptcha].freeze
    DELIVERY_MODES = %w[sync async].freeze
    DEFAULT_HONEYPOT = "_nibble_hp".freeze
    DEFAULT_RATE_LIMIT = { "requests" => 5, "per_minutes" => 1 }.freeze
    DEFAULT_SPAM_RETENTION_DAYS = 30
    DEFAULT_RESUME_DAYS = 7
    MESSAGES = {
      "rate_limited" => { one: "Too many submissions. Please try again in %{count} minute.", other: "Too many submissions. Please try again in %{count} minutes." },
      "captcha_failed" => "Please confirm you're not a robot.",
      "captcha_unavailable" => "This form can't take submissions right now. Please try again later.",
      "client.too_large" => "The files are too large to send.",
      "client.generic" => "Something went wrong. Please try again.",
      "client.network" => "Something went wrong. Please check your connection and try again.",
      "client.choose" => "Choose one…",
      "client.send" => "Send message",
      "client.sending" => "Sending…",
      "client.next" => "Next",
      "client.checking" => "Checking…",
      "client.back" => "Back",
      "client.save_later" => "Save and finish later",
      "client.step" => "Step %{step} of %{total}",
      "client.check_answers" => "Please check these answers:",
      "client.required_note" => "Fields marked * are required.",
      "client.required" => "(required)",
      "mail.submission.visitor_heading" => "Your submission",
      "mail.submission.staff_heading" => "New submission",
      "mail.submission.visitor_intro" => "Thanks for filling in %{title} on %{site}. Here's what you sent.",
      "mail.submission.staff_intro" => "Someone filled in %{title} on %{site}. Here's what they sent.",
      "mail.submission.reply_to" => "Reply to this email to answer them at %{email}.",
      "mail.submission.open" => "Open this submission in the Control Plane",
      "mail.submission.subject" => "New submission: %{title}",
      "mail.resume.heading" => "Finish filling in %{title}",
      "mail.resume.intro" => "You saved %{title} on %{site} to finish later. Open this link to carry on where you left off.",
      "mail.resume.intro_text" => "You saved %{title} on %{site} to finish later. Open this link to carry on where you left off:",
      "mail.resume.button" => "Finish the form",
      "mail.resume.note" => "The link works until %{expires}. Files you attached aren't kept, so attach them again before you send the form. If you didn't ask for this, ignore this email and what was saved is deleted when the link expires.",
      "resume.saved" => { one: "We've emailed you a link to finish this form. It works for %{count} day.", other: "We've emailed you a link to finish this form. It works for %{count} days." },
      "resume.email" => "Enter your email address so we can send you a link to finish later.",
      "resume.failed" => "We couldn't send the email. Please try again.",
      "resume.too_large" => "There's too much here to save. Please send the form instead.",
      "resume.expired" => "This link has expired or the form has already been sent. Please start again."
    }.freeze
    DEFAULT_CLOSED_MESSAGE = "This form isn't taking submissions right now.".freeze
    LIMIT_KEYS = %w[max_submissions opens_at closes_at closed_message unique].freeze
    SCHEDULE_LIMITS = %w[max_submissions opens_at closes_at].freeze
    UNIQUE_FIELDTYPES = %w[text textarea integer decimal select radio date button_group].freeze
    AUTOFILL_NAMES = /name|mail|phone|tel|address|street|city|zip|postal|country|company|organi[sz]ation|website|url|homepage|user|login/i

    Form = Data.define(:item) do
      def handle = item.handle
      def title(locale = nil) = Localized.resolve(item["title"], locale)
      def sectioned? = item["sections"].present? && item["fields"].nil?
      def section_items = Array(item["sections"]).map { |section| section.is_a?(Hash) ? section : {} }

      def fields(schema: Nibble.schema)
        return Fields.new(item["fields"], schema:, source: item.path, key: "fields") unless sectioned?

        Fields.new(section_items.flat_map { |section| Array(section["fields"]) }, schema:, source: item.path, key: "sections")
      end

      def sections(schema: Nibble.schema, locale: nil)
        return unless sectioned?

        section_items.map do |section|
          { "display" => Localized.resolve(section["display"], locale), "instructions" => Localized.resolve(section["instructions"], locale),
            "fields" => Fields.new(section["fields"], schema:, source: item.path, key: "sections") }
        end
      end

      def steps? = item["steps"] == true && sectioned?
      def resume? = item["resume"] == true
      def resume_email = item["resume_email"]
      def resume_days = item["resume_days"] || DEFAULT_RESUME_DAYS
      def store? = item["store"] != false
      def encrypted_handles = fields.all.values.select { |field| field.get("encrypt") == true }.map(&:handle)
      def spam = item["spam"].to_h
      def honeypot = spam["honeypot"] == false ? nil : spam["honeypot"].presence || DEFAULT_HONEYPOT
      def rate_limit = DEFAULT_RATE_LIMIT.merge(spam["rate_limit"].to_h)
      def captcha? = spam["captcha"] == true
      def min_seconds = spam["min_seconds"]
      def max_links = spam["max_links"]
      def spam_retention_days = spam.fetch("retention_days", DEFAULT_SPAM_RETENTION_DAYS)
      def notify = Array(item["notify"])
      def deliveries = Array(item["api"]).map { |delivery| { "mode" => "async" }.merge(delivery) }
      def cp_notify? = item["cp_notify"] == true
      def handler = item["handler"].presence
      def success(locale = nil)
        success = item["success"].to_h
        message = Localized.resolve(success["message"], locale)
        return success unless message.is_a?(String)

        success.merge("message" => Notify::Template.new(form: self, locale:).render(message).to_s)
      end
      def retention_days = item["retention_days"]
      def limits = item["limits"].is_a?(Hash) ? item["limits"] : {}
      def unique = Array(limits["unique"])
      def closed_message = limits["closed_message"].presence || DEFAULT_CLOSED_MESSAGE
      def uncacheable? = limits.slice(*SCHEDULE_LIMITS).any? || !min_seconds.nil?

      def closed?(now = Time.current)
        opens_at, closes_at = limits.values_at("opens_at", "closes_at").map { |value| Forms.time(value) }
        (opens_at && now < opens_at) || (closes_at && now >= closes_at) || full?
      end

      def full?
        max = limits["max_submissions"]
        store? && max.is_a?(Integer) && Records::FormSubmission.kept.where(form: handle).count >= max
      end
    end

    mattr_accessor :handlers, default: {}

    class << self
      def register_handler(name, handler) = handlers[name.to_s] = handler

      def find(handle, schema: Nibble.schema) = (item = schema.find(:forms, handle)) && Form.new(item:)
      def all(schema: Nibble.schema) = schema.forms.map { |item| Form.new(item:) }

      def message(key, locale, **values)
        default = MESSAGES.fetch(key)
        I18n.t("nibble.forms.#{key}", locale: Localized.i18n_locale(locale), default:, **values)
      end

      def time(value)
        value.is_a?(String) ? Time.zone.iso8601(value) : nil
      rescue ArgumentError
        nil
      end

      def display_value(field, value, locale = nil)
        return field.fieldtype.display(value) if field.fieldtype.respond_to?(:display)

        labels = field.fieldtype.respond_to?(:options) ? field.fieldtype.options(locale).to_h { |option| [ option["value"].to_s, option["label"].to_s ] } : {}
        case value
        when Array then value.map { |item| item.is_a?(Hash) ? item["filename"].to_s : labels.fetch(item.to_s, item.to_s) }
        when true then "Yes"
        when false then "No"
        when nil then nil
        else labels.fetch(value.to_s, value.to_s)
        end
      end

      def warnings(form)
        return [] unless form.honeypot&.match?(AUTOFILL_NAMES)

        [ "spam.honeypot '#{form.honeypot}' looks like a field browsers and password managers fill in, so real enquiries may be caught as spam" ]
      end

      def problems(form, schema:)
        problems = section_problems(form)
        form.fields(schema:).all.each_value do |field|
          problems << "field '#{field.handle}' uses '#{field.type}', which can't be used on a public form" unless PUBLIC_FIELDTYPES.include?(field.type)
          problems << "field handle '#{field.handle}' clashes with the honeypot" if field.handle == form.honeypot
          problems.concat(hidden_problems(field))
          problems.concat(encrypt_problems(form, field))
        end
        problems.concat(Uploads.problems(form, schema:))
        problems.concat(Calculations.problems(form.fields(schema:)))
        problems.concat(spam_problems(form))
        problems.concat(limit_problems(form, schema))
        problems.concat(resume_problems(form, schema))
        handles = form.fields(schema:).handles
        form.notify.each_with_index { |notify, index| problems.concat(notify_problems(notify, index, handles)) }
        form.deliveries.each_with_index { |delivery, index| problems.concat(delivery_problems(delivery, index, schema)) }
        problems << "success needs a message or a redirect" unless form.item["success"].blank? || form.item["success"]["message"].present? || redirect?(form.success["redirect"])
        problems.concat(template_problems(form.item["success"]["message"], "success.message", [])) if form.item["success"].is_a?(Hash) && form.item["success"]["message"].is_a?(String)
        problems << "handler '#{form.handler}' isn't registered" if form.handler && !handlers.key?(form.handler)
        problems << "submit_label must be text, or text per locale" unless form.item["submit_label"].nil? || Schema::Rules::TEXT.(form.item["submit_label"])
        problems << "retention_days must be a positive number of days" unless form.retention_days.nil? || form.retention_days.to_i.positive?
        problems
      end

      def locale_problems(form, schema:, locales:)
        texts = { "title" => form.item["title"], "submit_label" => form.item["submit_label"], "success.message" => form.item["success"].to_h["message"], "limits.closed_message" => form.item["limits"].to_h["closed_message"] }
        form.section_items.each_with_index do |section, index|
          texts.merge!("sections.#{index}.display" => section["display"], "sections.#{index}.instructions" => section["instructions"])
        end
        form.fields(schema:).all.each_value do |field|
          (%w[display instructions] + Definition::LOCALIZED_CONFIG).each { |key| texts["field '#{field.handle}' #{key}"] = field.get(key) }
          next unless Definition::OPTION_TYPES.include?(field.type)

          option_labels(field.fieldtype.config("options")).each { |value, label| texts["field '#{field.handle}' option '#{value}'"] = label }
        end
        texts.flat_map { |label, text| Localized.problems(text, locales, label) }
      end

      private

      def option_labels(raw)
        return raw.to_a if raw.is_a?(Hash)

        Array(raw).filter_map { |item| [ item["key"] || item["value"], item["label"] ] if item.is_a?(Hash) }
      end

      def hidden_problems(field)
        hidden = field.get("hidden") == true
        problems = []
        problems << "field '#{field.handle}' has `prefill` but isn't `hidden: true`, so the visitor would see and edit it" if field.config.key?("prefill") && !hidden
        problems << "field '#{field.handle}' has `value` but isn't `hidden: true`" if field.config.key?("value") && !hidden
        problems << "field '#{field.handle}' is hidden, which a files field can't be" if hidden && field.type == "files"
        problems
      end

      def encrypt_problems(form, field)
        return [] unless field.get("encrypt") == true
        return [ "field '#{field.handle}' can't be encrypted: a files field keeps its files in storage, not in the submission" ] if field.type == "files"
        return [ "field '#{field.handle}' has `encrypt: true` but the form has `store: false`, so nothing is stored to encrypt" ] unless form.store?

        []
      end

      def section_problems(form)
        return [ "give `fields` or `sections`, not both" ] if !form.item["fields"].nil? && !form.item["sections"].nil?
        return [ "needs `fields` or `sections`" ] if form.item["fields"].nil? && form.item["sections"].nil?

        Array(form.item["sections"]).each_index.filter_map do |index|
          section = form.item["sections"][index]
          "sections.#{index} needs a `fields` list" unless section.is_a?(Hash) && section["fields"].is_a?(Array)
        end
      end

      def spam_problems(form)
        problems = []
        unless form.rate_limit.values_at("requests", "per_minutes").all? { |value| value.is_a?(Integer) && value.positive? }
          problems << "spam.rate_limit needs positive requests and per_minutes"
        end
        problems << "spam.captcha must be true or false" unless [ nil, true, false ].include?(form.spam["captcha"])
        problems << "spam.retention_days must be a positive number of days" unless form.spam_retention_days.to_i.positive?
        problems << "spam.min_seconds must be a positive whole number of seconds" unless form.min_seconds.nil? || (form.min_seconds.is_a?(Integer) && form.min_seconds.positive?)
        problems << "spam.max_links must be a whole number, 0 or more" unless form.max_links.nil? || (form.max_links.is_a?(Integer) && form.max_links >= 0)
        problems
      end

      def limit_problems(form, schema)
        limits = form.limits
        problems = (limits.keys - LIMIT_KEYS).map { |key| "limits.#{key} isn't a limit; use #{LIMIT_KEYS.to_sentence(last_word_connector: ' or ')}" }
        problems << "limits.max_submissions must be a positive whole number" if limits.key?("max_submissions") && !(limits["max_submissions"].is_a?(Integer) && limits["max_submissions"].positive?)
        times = %w[opens_at closes_at].select { |key| limits.key?(key) }.to_h { |key| [ key, Forms.time(limits[key]) ] }
        times.each { |key, value| problems << "limits.#{key} must be a quoted date and time like \"2026-11-01T09:00\"" unless value }
        problems << "limits.closes_at must be after limits.opens_at" if times.values.compact.size == 2 && times["closes_at"] <= times["opens_at"]
        problems << "limits.closed_message must be text, or text per locale" if limits.key?("closed_message") && !(limits["closed_message"].is_a?(String) || (limits["closed_message"].is_a?(Hash) && limits["closed_message"].values.all?(String)))
        fields = form.fields(schema:).all
        unless limits["unique"].nil? || (limits["unique"].is_a?(Array) && limits["unique"].all? { |handle| unique_field?(fields[handle.to_s]) })
          problems << "limits.unique must list the form's text, number, single-choice or date fields"
        end
        %w[max_submissions unique].each do |key|
          problems << "limits.#{key} needs the form to store submissions, which is what it counts against" if limits.key?(key) && !form.store?
        end
        problems
      end

      def resume_problems(form, schema)
        problems = []
        problems << "steps needs `sections`: each section is a step" if form.item["steps"] == true && !form.sectioned?
        return problems unless form.resume?

        field = form.fields(schema:).get(form.resume_email.to_s)
        unless field&.type == "text" && field.get("hidden") != true
          problems << "resume_email must name one of the form's text fields, where the visitor gives the address to send the link to"
        end
        problems << "resume_days must be a positive number of days" unless form.resume_days.is_a?(Integer) && form.resume_days.positive?
        problems << "resume needs the form to store submissions, since it keeps what was entered until the visitor comes back" unless form.store?
        problems
      end

      def unique_field?(field) = field && UNIQUE_FIELDTYPES.include?(field.type) && field.get("multiple") != true

      def notify_problems(notify, index, handles)
        return [ "notify.#{index} must be a mapping with a `to` address" ] unless notify.is_a?(Hash) && notify["to"].present?

        problems = []
        if notify.key?("fields") && !(notify["fields"].is_a?(Array) && (notify["fields"] - handles).empty?)
          problems << "notify.#{index}.fields must be a list of the form's field handles"
        end
        problems << "notify.#{index}.reply_to must be one of the form's field handles" if notify.key?("reply_to") && !handles.include?(notify["reply_to"])
        %w[to cc bcc].each do |key|
          Array(notify[key]).each { |address| problems.concat(recipient_problems(address, "notify.#{index}.#{key}", handles)) }
        end
        %w[subject message].each do |key|
          problems.concat(template_problems(notify[key], "notify.#{index}.#{key}", handles)) if notify.key?(key)
        end
        Conditions::KEYS.each do |key|
          next unless notify.key?(key)

          unless notify[key].is_a?(Hash) && notify[key].keys.all? { |handle| handles.include?(handle.to_s) }
            problems << "notify.#{index}.#{key} must map the form's field handles to the values to match"
          end
        end
        problems
      end

      def recipient_problems(address, label, handles)
        message = "#{label} must be an address, {field.<handle>} or {global.<set>.<field>}"
        return [ message ] unless address.is_a?(String)
        return [] unless address.include?("{")
        return [ message ] unless address.strip.match?(/\A\{(field|global)\.[A-Za-z0-9_.]+\}\z/)

        template_problems(address, label, handles)
      end

      def template_problems(value, label, handles)
        return [ "#{label} must be text" ] unless value.is_a?(String)

        value.scan(Outbound::Template::PATTERN).filter_map do |kind, name|
          case kind
          when "field" then "#{label} names {field.#{name}}, which isn't one of the form's field handles" unless handles.include?(name)
          when "form" then "#{label} can use {form.title} only" unless name == "title"
          when "global" then global_problem(label, name)
          else "#{label} can't use {#{kind}.#{name}} in an email"
          end
        end
      end

      def global_problem(label, name)
        handle, field = name.split(".", 2)
        found = field && handle != Integrations::HANDLE && Nibble.schema.find(:globals, handle) && Records::GlobalSet.new(handle:).blueprint_fields.get(field)
        "#{label} names {global.#{name}}, which isn't a field of a global set" unless found
      end

      def delivery_problems(delivery, index, schema)
        return [ "api.#{index} must be a mapping" ] unless delivery.is_a?(Hash)

        problems = []
        if delivery["use"].present? == delivery["url"].present?
          problems << "api.#{index} needs either `use` (an API connection) or `url`"
        elsif delivery["use"].present? && !schema.find(:apis, delivery["use"])
          problems << "api.#{index} uses the API connection '#{delivery['use']}', which isn't in the schema"
        elsif delivery["url"].present? && !delivery["url"].match?(%r{\Ahttps?://})
          problems << "api.#{index}.url must be an absolute http(s) URL"
        end
        problems << "api.#{index}.mode must be sync or async" unless DELIVERY_MODES.include?(delivery["mode"])
        problems << "api.#{index}.body must be a mapping" if delivery.key?("body") && !delivery["body"].is_a?(Hash)
        problems << "api.#{index}.method must be post, put or patch" unless %w[post put patch].include?(delivery.fetch("method", "post").to_s.downcase)
        problems << "api.#{index}.format must be json or form" unless %w[json form].include?(delivery.fetch("format", "json").to_s)
        problems
      end

      def redirect?(value) = value.is_a?(String) && value.match?(%r{\A(/|https?://)})
    end
  end
end
