module Nibble
  module Forms
    class Submit
      Result = Data.define(:status, :submission, :errors, :values) do
        def ok? = status == :ok
      end

      PREFILL_LIMIT = 500
      SPAM_VALUE = [ String, Numeric, TrueClass, FalseClass ].freeze

      mattr_accessor :rate_limit_store, default: -> { Rails.cache }

      def self.call(form, params, ip: nil, user_agent: nil, locale: nil, query: {}) = new(form, params, ip:, user_agent:, locale:, query:).call

      def self.not_spam(form, submission, user:, ip: nil)
        new(form, submission.data, ip: nil, user_agent: submission.user_agent, locale: submission.locale).not_spam(submission, user:, ip:)
      end

      def initialize(form, params, ip:, user_agent:, locale:, query: {})
        @form = form
        @query = query.to_h.stringify_keys
        @params = params.to_h.stringify_keys
        @ip_hash = Records::FormSubmission.hash_ip(ip)
        @ip = ip
        @user_agent = user_agent.to_s.truncate(255).presence
        @locale = Nibble.config.locale(locale)&.code || Nibble.config.default_locale.code
      end

      def call
        return result(:rate_limited, errors: { "base" => [ "Too many submissions. Please try again in a minute." ] }) if rate_limited?
        return spam! if @form.honeypot && @params[@form.honeypot].present?
        return result(:invalid, errors: { "base" => [ captcha_message ] }) unless captcha_passed?

        fields = @form.fields
        values = @params.slice(*fields.handles).merge(hidden_values(fields))
        errors = errors_in(fields, values)
        return result(:invalid, errors:, values:) if errors.any?

        data, blob_ids = upload(fields, values)
        store(fields.add_values(data).process.values.compact, blob_ids)
      end

      def not_spam(submission, user:, ip:)
        return result(:not_spam, submission:) unless submission.status == "spam"
        return result(:cleared, submission:) if submission.data.blank?

        fields = @form.fields
        values = @params.slice(*fields.handles)
        errors = errors_in(fields, values)
        return result(:invalid, submission:, errors:, values:) if errors.any?

        data = fields.add_values(values).process.values.compact
        return result(:not_spam, submission:) unless claim(submission, data, user:, ip:)

        outcome = deliver(submission, data)
        outcome.ok? ? outcome : result(:rejected, submission:, errors: outcome.errors, values: data)
      end

      private

      def step_errors(fields, values)
        fields.all.values.each_with_object({}) do |field, found|
          step = field.get("step")
          next unless field.type == "integer" && step.to_i.positive? && values[field.handle].to_s.match?(/\A-?\d+\z/)

          from = field.get("min").to_i
          next if (values[field.handle].to_i - from) % step.to_i == 0

          found[field.handle] = [ Validation.message("step", attribute: field.display, override: field.get("messages", {})["step"], locale: @locale,
            default: "The %{attribute} field must go up in steps of %{step} (from %{from}).", step:, min: from, from:) ]
        end
      end

      def hidden_values(fields)
        fields.all.values.select { |field| field.get("hidden") == true }.to_h do |field|
          name = field.get("prefill", {})["query"]
          posted = (@params[field.handle] if name)
          queried = @query[name] if name
          queried = queried.truncate(PREFILL_LIMIT, omission: "") if queried.is_a?(String)
          [ field.handle, posted.presence || queried.presence || field.get("value") ]
        end.compact
      end

      def result(status, submission: nil, errors: {}, values: {}) = Result.new(status:, submission:, errors:, values:)

      def errors_in(fields, values)
        errors = Validator.new(fields, replacements: { "type" => "form_submission" }, locale: @locale).validate(values).errors
        step_errors(fields, values).merge(errors)
      end

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

        settings = Integrations.captcha or return captcha_unavailable!
        Captcha.verify(settings, Captcha.token(@params), ip: @ip)
      end

      def captcha_unavailable!
        @captcha_unavailable = true
        Rails.logger.warn("Form '#{@form.handle}' has captcha: true but Integrations has no CAPTCHA keys, so its submissions are refused")
        false
      end

      def captcha_message
        @captcha_unavailable ? "This form can't take submissions right now. Please try again later." : "Please confirm you're not a robot."
      end

      def spam!
        return result(:ok) unless @form.store?

        fields = @form.fields
        files = fields.all.values.select { |field| field.type == "files" }.map(&:handle)
        data = @params.slice(*fields.handles).except(*files).select { |_, value| plain?(value) }
        submission = Records::FormSubmission.create!(form: @form.handle, status: "spam", data:, ip_hash: @ip_hash, user_agent: @user_agent, locale: @locale)
        result(:ok, submission:)
      end

      def plain?(value) = Array.wrap(value).all? { |item| SPAM_VALUE.any? { |type| item.is_a?(type) } }

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

        submission = Records::FormSubmission.transaction do
          Records::FormSubmission.create!(form: @form.handle, data:, ip_hash: @ip_hash, user_agent: @user_agent, locale: @locale, deliveries:).tap do |record|
            record.files.attach(ActiveStorage::Blob.where(id: blob_ids).to_a) if blob_ids.any?
            announce(record)
          end
        end
        deliver(submission, data)
      end

      def claim(submission, data, user:, ip:)
        Records::FormSubmission.transaction do
          next false if Records::FormSubmission.where(id: submission.id, status: "spam").update_all(status: "received").zero?

          submission.reload.update!(data:, deliveries:)
          announce(submission)
          Records::AuditEntry.create!(action: "form.not_spam", actor_type: "user", actor_id: user.id, subject_type: submission.record_type,
            subject_id: submission.id, changeset: { "form" => @form.handle, "status" => %w[spam received] }, ip:, created_at: Time.current)
        end
      end

      def deliveries
        @form.deliveries.each_with_index.map do |delivery, index|
          { "key" => "api.#{index}", "target" => delivery["use"] || delivery["url"], "mode" => delivery["mode"], "status" => "pending", "attempts" => 0 }
        end
      end

      def announce(record) = Events.publish("form.submitted", "type" => record.record_type, "id" => record.id, "form" => @form.handle, "locale" => @locale)

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
