module Nibble
  module Forms
    PUBLIC_FIELDTYPES = %w[text textarea integer toggle select radio checkboxes date files].freeze
    CAPTCHA_PROVIDERS = %w[turnstile recaptcha].freeze
    DELIVERY_MODES = %w[sync async].freeze
    DEFAULT_HONEYPOT = "_nibble_hp".freeze
    DEFAULT_RATE_LIMIT = { "requests" => 5, "per_minutes" => 1 }.freeze
    DEFAULT_SPAM_RETENTION_DAYS = 30
    AUTOFILL_NAMES = /name|mail|phone|tel|address|street|city|zip|postal|country|company|organi[sz]ation|website|url|homepage|user|login/i

    Form = Data.define(:item) do
      def handle = item.handle
      def title = item["title"]
      def sectioned? = item["sections"].present? && item["fields"].nil?
      def section_items = Array(item["sections"]).map { |section| section.is_a?(Hash) ? section : {} }

      def fields(schema: Nibble.schema)
        return Fields.new(item["fields"], schema:, source: item.path, key: "fields") unless sectioned?

        Fields.new(section_items.flat_map { |section| Array(section["fields"]) }, schema:, source: item.path, key: "sections")
      end

      def sections(schema: Nibble.schema)
        return unless sectioned?

        section_items.map do |section|
          section.slice("display", "instructions").merge("fields" => Fields.new(section["fields"], schema:, source: item.path, key: "sections"))
        end
      end

      def store? = item["store"] != false
      def spam = item["spam"].to_h
      def honeypot = spam["honeypot"] == false ? nil : spam["honeypot"].presence || DEFAULT_HONEYPOT
      def rate_limit = DEFAULT_RATE_LIMIT.merge(spam["rate_limit"].to_h)
      def captcha? = spam["captcha"] == true
      def spam_retention_days = spam.fetch("retention_days", DEFAULT_SPAM_RETENTION_DAYS)
      def notify = Array(item["notify"])
      def deliveries = Array(item["api"]).map { |delivery| { "mode" => "async" }.merge(delivery) }
      def cp_notify? = item["cp_notify"] == true
      def handler = item["handler"].presence
      def success
        success = item["success"].to_h
        return success unless success["message"].is_a?(String)

        success.merge("message" => Notify::Template.new(form: self).render(success["message"]).to_s)
      end
      def retention_days = item["retention_days"]
    end

    mattr_accessor :handlers, default: {}

    class << self
      def register_handler(name, handler) = handlers[name.to_s] = handler

      def find(handle, schema: Nibble.schema) = (item = schema.find(:forms, handle)) && Form.new(item:)
      def all(schema: Nibble.schema) = schema.forms.map { |item| Form.new(item:) }

      def display_value(field, value)
        labels = field.fieldtype.respond_to?(:options) ? field.fieldtype.options.to_h { |option| [ option["value"].to_s, option["label"].to_s ] } : {}
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
        end
        problems.concat(Uploads.problems(form, schema:))
        problems.concat(spam_problems(form))
        handles = form.fields(schema:).handles
        form.notify.each_with_index { |notify, index| problems.concat(notify_problems(notify, index, handles)) }
        form.deliveries.each_with_index { |delivery, index| problems.concat(delivery_problems(delivery, index, schema)) }
        problems << "success needs a message or a redirect" unless form.item["success"].blank? || form.item["success"]["message"].present? || redirect?(form.success["redirect"])
        problems.concat(template_problems(form.item["success"]["message"], "success.message", [])) if form.item["success"].is_a?(Hash) && form.item["success"]["message"].is_a?(String)
        problems << "handler '#{form.handler}' isn't registered" if form.handler && !handlers.key?(form.handler)
        problems << "retention_days must be a positive number of days" unless form.retention_days.nil? || form.retention_days.to_i.positive?
        problems
      end

      private

      def hidden_problems(field)
        hidden = field.get("hidden") == true
        problems = []
        problems << "field '#{field.handle}' has `prefill` but isn't `hidden: true`, so the visitor would see and edit it" if field.config.key?("prefill") && !hidden
        problems << "field '#{field.handle}' has `value` but isn't `hidden: true`" if field.config.key?("value") && !hidden
        problems << "field '#{field.handle}' is hidden, which a files field can't be" if hidden && field.type == "files"
        problems
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
        problems
      end

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
