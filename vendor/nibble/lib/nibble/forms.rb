module Nibble
  module Forms
    PUBLIC_FIELDTYPES = %w[text textarea integer toggle select radio checkboxes date files].freeze
    CAPTCHA_PROVIDERS = %w[turnstile recaptcha].freeze
    DELIVERY_MODES = %w[sync async].freeze
    DEFAULT_HONEYPOT = "_nibble_hp".freeze
    DEFAULT_RATE_LIMIT = { "requests" => 5, "per_minutes" => 1 }.freeze

    Form = Data.define(:item) do
      def handle = item.handle
      def title = item["title"]
      def fields(schema: Nibble.schema) = Fields.new(item["fields"], schema:, source: item.path, key: "fields")
      def store? = item["store"] != false
      def spam = item["spam"].to_h
      def honeypot = spam["honeypot"] == false ? nil : spam["honeypot"].presence || DEFAULT_HONEYPOT
      def rate_limit = DEFAULT_RATE_LIMIT.merge(spam["rate_limit"].to_h)
      def captcha? = spam["captcha"] == true
      def notify = Array(item["notify"])
      def deliveries = Array(item["api"]).map { |delivery| { "mode" => "async" }.merge(delivery) }
      def cp_notify? = item["cp_notify"] == true
      def handler = item["handler"].presence
      def success = item["success"].to_h
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

      def problems(form, schema:)
        problems = []
        form.fields(schema:).all.each_value do |field|
          problems << "field '#{field.handle}' uses '#{field.type}', which can't be used on a public form" unless PUBLIC_FIELDTYPES.include?(field.type)
          problems << "field handle '#{field.handle}' clashes with the honeypot" if field.handle == form.honeypot
        end
        problems.concat(Uploads.problems(form, schema:))
        problems.concat(spam_problems(form))
        handles = form.fields(schema:).handles
        form.notify.each_with_index { |notify, index| problems.concat(notify_problems(notify, index, handles)) }
        form.deliveries.each_with_index { |delivery, index| problems.concat(delivery_problems(delivery, index, schema)) }
        problems << "success needs a message or a redirect" unless form.success.empty? || form.success["message"].present? || redirect?(form.success["redirect"])
        problems << "handler '#{form.handler}' isn't registered" if form.handler && !handlers.key?(form.handler)
        problems << "retention_days must be a positive number of days" unless form.retention_days.nil? || form.retention_days.to_i.positive?
        problems
      end

      private

      def spam_problems(form)
        problems = []
        unless form.rate_limit.values_at("requests", "per_minutes").all? { |value| value.is_a?(Integer) && value.positive? }
          problems << "spam.rate_limit needs positive requests and per_minutes"
        end
        problems << "spam.captcha must be true or false" unless [ nil, true, false ].include?(form.spam["captcha"])
        problems
      end

      def notify_problems(notify, index, handles)
        return [ "notify.#{index} must be a mapping with a `to` address" ] unless notify.is_a?(Hash) && notify["to"].present?

        problems = []
        if notify.key?("fields") && !(notify["fields"].is_a?(Array) && (notify["fields"] - handles).empty?)
          problems << "notify.#{index}.fields must be a list of the form's field handles"
        end
        problems << "notify.#{index}.reply_to must be one of the form's field handles" if notify.key?("reply_to") && !handles.include?(notify["reply_to"])
        problems
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
