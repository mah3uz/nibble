module Nibble
  module Forms
    class Submit
      Result = Data.define(:status, :submission, :errors, :values) do
        def ok? = status == :ok
      end

      mattr_accessor :rate_limit_store, default: -> { Rails.cache }

      def self.call(form, params, ip: nil, user_agent: nil, locale: nil) = new(form, params, ip:, user_agent:, locale:).call

      def initialize(form, params, ip:, user_agent:, locale:)
        @form = form
        @params = params.to_h.stringify_keys
        @ip_hash = Records::FormSubmission.hash_ip(ip)
        @ip = ip
        @user_agent = user_agent.to_s.truncate(255).presence
        @locale = Nibble.config.locale(locale)&.code || Nibble.config.default_locale.code
      end

      def call
        return result(:rate_limited, errors: { "base" => [ "Too many submissions. Please try again in a minute." ] }) if rate_limited?
        return spam! if @form.honeypot && @params[@form.honeypot].present?
        return result(:invalid, errors: { "base" => [ "Please confirm you're not a robot." ] }) unless captcha_passed?

        fields = @form.fields
        values = @params.slice(*fields.handles)
        errors = Validator.new(fields, replacements: { "type" => "form_submission" }).validate(values).errors
        return result(:invalid, errors:, values:) if errors.any?

        data, blob_ids = upload(fields, values)
        store(fields.add_values(data).process.values.compact, blob_ids)
      end

      private

      def result(status, submission: nil, errors: {}, values: {}) = Result.new(status:, submission:, errors:, values:)

      def rate_limited?
        limit = @form.rate_limit
        window = limit["per_minutes"].minutes
        key = "nibble:forms:#{@form.handle}:#{@ip_hash || 'unknown'}:#{Time.current.to_i / window.to_i}"
        store = rate_limit_store.call
        count = store.increment(key, 1, expires_in: window) || (store.write(key, 1, expires_in: window) && 1)
        count.to_i > limit["requests"]
      end

      def captcha_passed?
        return true unless @form.captcha?

        settings = Integrations.captcha or return true
        Captcha.verify(settings, Captcha.token(@params), ip: @ip)
      end

      def spam!
        submission = Records::FormSubmission.create!(form: @form.handle, status: "spam", ip_hash: @ip_hash, user_agent: @user_agent, locale: @locale) if @form.store?
        result(:ok, submission:)
      end

      def upload(fields, values)
        handles = fields.all.values.select { |field| field.type == "files" }.map(&:handle)
        return [ values.except(*handles), [] ] unless @form.store?

        stored = []
        files = handles.to_h { |handle| [ handle, Array.wrap(values[handle]).map { |file| Uploads.store(file).tap { |meta| stored << meta["id"] } } ] }
        [ values.merge(files), stored ]
      rescue StandardError
        ActiveStorage::Blob.where(id: stored).find_each(&:purge)
        raise
      end

      def store(data, blob_ids = [])
        return deliver(nil, data) unless @form.store?

        deliveries = @form.deliveries.each_with_index.map do |delivery, index|
          { "key" => "api.#{index}", "target" => delivery["use"] || delivery["url"], "mode" => delivery["mode"], "status" => "pending", "attempts" => 0 }
        end
        submission = Records::FormSubmission.transaction do
          Records::FormSubmission.create!(form: @form.handle, data:, ip_hash: @ip_hash, user_agent: @user_agent, locale: @locale, deliveries:).tap do |record|
            record.files.attach(ActiveStorage::Blob.where(id: blob_ids).to_a) if blob_ids.any?
            Events.publish("form.submitted", "type" => record.record_type, "id" => record.id, "form" => @form.handle, "locale" => @locale)
          end
        end
        deliver(submission, data)
      end

      def deliver(submission, data)
        errors = {}
        @form.deliveries.each_with_index do |delivery, index|
          next enqueue(submission, data, index) unless delivery["mode"] == "sync"

          outcome = Deliver.call(@form, index, data, submission:)
          errors.merge!(outcome.errors) { |_, first, second| first + second } if outcome.rejected?
          enqueue(submission, data, index, attempt: 2) if outcome.status == "failed"
        end
        return result(:invalid, submission:, errors:, values: data) if errors.any?

        follow_up(submission, data)
        result(:ok, submission:, values: data)
      end

      def follow_up(submission, data)
        options = { submission_id: submission&.id, data: submission ? nil : data }
        Jobs::NotifySubmission.perform_later(@form.handle, **options) if @form.notify.any? || @form.cp_notify?
        Jobs::HandleSubmission.perform_later(@form.handle, **options) if @form.handler
      end

      def enqueue(submission, data, index, attempt: 1)
        wait = attempt > 1 ? Deliver.retry_policy(@form, index)["backoff_seconds"].seconds : 0
        Jobs::DeliverSubmission.set(wait:).perform_later(@form.handle, index, submission_id: submission&.id,
          data: submission ? nil : data, attempt:)
      end
    end
  end
end
