module Nibble
  module Forms
    class Deliver
      Outcome = Data.define(:status, :errors, :response_status, :error) do
        def delivered? = status == "delivered"
        def rejected? = status == "rejected"
      end

      DEFAULT_REJECTED = [ 400, 422 ].freeze

      def self.call(form, index, data, submission: nil) = new(form, index, data, submission:).call

      def self.retry!(submission, key)
        index = Integer(key.to_s.delete_prefix("api."))
        submission.update_delivery!(key, status: "pending", error: nil)
        Jobs::DeliverSubmission.perform_later(submission.form, index, submission_id: submission.id)
      end

      def self.retry_policy(form, index)
        delivery = form.deliveries.fetch(index)
        base = delivery["use"].present? ? Outbound::Connection.find(delivery["use"])&.retry_policy : nil
        (base || { "attempts" => 3, "backoff_seconds" => 30 }).merge(delivery["retry"].to_h)
      end

      def initialize(form, index, data, submission: nil)
        @form = form
        @delivery = form.deliveries.fetch(index)
        @key = "api.#{index}"
        @data = data.to_h
        @submission = submission
        @connection = @delivery["use"].presence && Outbound::Connection.find(@delivery["use"])
      end

      def call
        template = Outbound::Template.new(fields: @data)
        options = { purpose: "form:#{@form.handle}", owner: @submission, format: @delivery["format"] || "json",
                    body: @delivery["body"] || @data }
        method = @delivery["method"] || "post"
        response = if @connection
          @connection.request(method, @delivery["path"].to_s, template:, **options)
        else
          Outbound.request(method, template.render(@delivery["url"]), secrets: template.secrets_used, **options.merge(body: template.render(options[:body])))
        end
        record(classify(response))
      rescue Outbound::Refused, Outbound::Failed, Nibble::Error => error
        record(Outcome.new(status: "failed", errors: {}, response_status: nil, error: error.message))
      end

      private

      def mapping = (@connection&.error_mapping || {}).merge(@delivery["errors"].to_h)

      def classify(response)
        return Outcome.new(status: "delivered", errors: {}, response_status: response.status, error: nil) if response.ok?

        rejected = Array(mapping["status"].presence || DEFAULT_REJECTED).map(&:to_i)
        return Outcome.new(status: "failed", errors: {}, response_status: response.status, error: "HTTP #{response.status}") unless rejected.include?(response.status)

        Outcome.new(status: "rejected", errors: remote_errors(response), response_status: response.status, error: "HTTP #{response.status}")
      end

      def remote_errors(response)
        found = mapping["path"].present? ? response.json&.dig(*mapping["path"].split(".")) : response.json&.dig("errors")
        renames = @delivery["error_fields"].to_h
        pairs = case found
        when Hash then found.map { |field, messages| [ field, Array(messages).first ] }
        when Array then found.filter_map { |item| item.is_a?(Hash) ? [ item[mapping["field"] || "field"], item[mapping["message"] || "message"] ] : [ nil, item ] }
        else []
        end
        errors = pairs.each_with_object({}) do |(field, message), all|
          field = renames.fetch(field.to_s, field).to_s
          field = "base" unless @form.fields.handles.include?(field)
          (all[field] ||= []) << (message.presence || "was rejected").to_s
        end
        errors.presence || { "base" => [ "The submission was rejected. Please check it and try again." ] }
      end

      def record(outcome)
        return outcome unless @submission

        previous = @submission.delivery(@key).to_h
        @submission.update_delivery!(@key, status: outcome.status, attempts: previous["attempts"].to_i + 1,
          response_status: outcome.response_status, error: outcome.error, errors: outcome.errors.presence, at: Time.current.utc.iso8601)
        outcome
      end
    end
  end
end
