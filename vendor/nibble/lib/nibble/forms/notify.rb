module Nibble
  module Forms
    class Notify
      Plan = Data.define(:index, :to, :cc, :bcc, :subject, :message, :visitor, :link, :locale)

      class Skipped < StandardError; end

      class Template < Outbound::Template
        def initialize(fields: {}, form: nil, locale: nil)
          super(fields:, form:)
          @locale = locale
        end

        private

        def lookup(kind, name)
          return "{#{kind}.#{name}}" if %w[secret config].include?(kind)
          return (@form&.title(@locale) || @form&.handle) if kind == "form" && name == "title"

          super
        end
      end

      def self.call(form, data, submission: nil, locale: nil) = new(form, data, submission, locale).call

      def initialize(form, data, submission, locale = nil)
        @form = form
        @data = data.to_h
        @submission = submission
        @locale = Nibble.config.locale(locale)&.code || Nibble.config.default_locale.code
        @templates = {}
      end

      def call = @form.notify.each_index { |index| deliver(index) }

      def plan(index)
        notify = @form.notify.fetch(index)
        return unless Conditions.visible?(notify.slice(*Conditions::KEYS), values: @data)

        to, visitor = recipients(notify["to"])
        raise Skipped, "no valid recipient for `to`" if to.empty?

        cc, cc_visitor = recipients(notify["cc"])
        bcc, bcc_visitor = recipients(notify["bcc"])
        visitor ||= cc_visitor || bcc_visitor
        locale = visitor ? @locale : Nibble.config.default_locale.code
        Plan.new(index:, to:, cc:, bcc:, subject: line(notify["subject"], locale), message: text(notify["message"], locale), visitor:, link:, locale:)
      end

      private

      def deliver(index)
        planned = plan(index) or return
        Nibble::FormsMailer.submission(@form.handle, index, @data, planned).deliver_now
        record(index, planned.to.join(", "), "sent")
      rescue Skipped => error
        Rails.logger.warn("Form '#{@form.handle}' notify.#{index} skipped: #{error.message}")
        record(index, configured(index), "skipped", error.message)
      rescue StandardError => error
        Rails.logger.error("Form '#{@form.handle}' notify.#{index} failed: #{error.message}")
        record(index, planned ? planned.to.join(", ") : configured(index), "failed", error.message)
      end

      def configured(index) = Array(@form.notify[index]["to"]).join(", ")

      def record(index, target, status, error = nil)
        @submission&.record_delivery!("notify.#{index}", "target" => target, "configured" => configured(index), "mode" => "email",
          "status" => status, "error" => error, "at" => Time.current.utc.iso8601)
      end

      def recipients(value)
        visitor = false
        addresses = Array(value).flat_map do |item|
          item = item.to_s.strip
          next [ item ] unless item.include?("{")

          visitor ||= item.start_with?("{field.")
          resolved = template.render(item)
          candidates = item.start_with?("{global.") ? resolved.to_s.split(/[,;]/).map(&:strip) : [ resolved.to_s ]
          candidates.select { |address| address.match?(URI::MailTo::EMAIL_REGEXP) }
        end
        [ addresses.uniq, visitor ]
      end

      def line(value, locale = nil) = value.present? ? template(locale).render(value.to_s).gsub(/\s*[\r\n]+\s*/, " ").strip.presence : nil
      def text(value, locale = nil) = value.present? ? template(locale).render(value.to_s).strip.presence : nil

      def template(locale = nil)
        @templates[locale] ||= Template.new(fields: display_values(locale), form: @form, locale:)
      end

      def display_values(locale)
        @form.fields.all.values.reject(&:display_only?).to_h { |field| [ field.handle, Array(Forms.display_value(field, @data[field.handle], locale)).join(", ") ] }
      end

      def link
        return unless @submission&.persisted?

        "#{Nibble.config.url.to_s.chomp('/')}/cp/forms/#{@form.handle}/submissions/#{@submission.id}"
      end
    end
  end
end
