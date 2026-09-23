module Nibble
  module Webhooks
    EVENTS = {
      "record.*" => "Any content change",
      "record.created" => "Created",
      "record.saved" => "Saved",
      "record.published" => "Published",
      "record.scheduled" => "Scheduled",
      "record.unpublished" => "Unpublished",
      "record.trashed" => "Trashed",
      "record.restored" => "Restored",
      "record.moved" => "Moved",
      "workflow.transitioned" => "Workflow status changed",
      "form.submitted" => "Form submitted"
    }.freeze
    PATTERNS = %w[record.* workflow.* form.*].freeze
    TEST_EVENT = "webhook.test".freeze
    BACKOFF = [ 1.minute, 5.minutes, 30.minutes, 2.hours, 5.hours, 10.hours, 24.hours ].freeze
    MAX_ATTEMPTS = BACKOFF.size + 1
    DISABLE_AFTER = 20
    RETENTION = 30.days
    MANAGE_ABILITY = "webhooks.manage".freeze
    PRIVATE_KEYS = %w[ip].freeze

    module_function

    def signature(secret, timestamp, body) = "t=#{timestamp},v1=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{body}")}"

    def body(delivery)
      id = delivery.event_id ? "evt_#{delivery.event_id}" : "evt_test_#{delivery.id}"
      { "id" => id, "event" => delivery.event, "created_at" => delivery.created_at.utc.iso8601, "data" => delivery.payload }.to_json
    end

    def test(webhook)
      delivery = webhook.deliveries.create!(event: TEST_EVENT, payload: { "webhook" => webhook.name })
      deliver(delivery)
    end

    def resend(delivery) = enqueue(delivery.webhook, delivery.event, delivery.payload, event_id: delivery.event_id)

    def enqueue(webhook, event, payload, event_id: nil)
      delivery = webhook.deliveries.create!(event:, event_id:, payload: payload.except(*PRIVATE_KEYS))
      Jobs::DeliverWebhook.perform_later(delivery.id)
      delivery
    end

    def deliver(delivery)
      webhook = delivery.webhook
      body = body(delivery)
      timestamp = Time.current.to_i
      headers = { "X-Nibble-Event" => delivery.event, "X-Nibble-Delivery" => delivery.id.to_s,
                  "X-Nibble-Signature" => signature(webhook.secret, timestamp, body), "Content-Type" => "application/json" }
      response = Outbound.request(:post, webhook.url, purpose: "webhook", body:, headers:, owner: delivery)
      response.ok? ? succeeded(delivery, response.status) : failed(delivery, response.status, "HTTP #{response.status}")
    rescue Outbound::Refused, Outbound::Failed => error
      failed(delivery, nil, error.message)
    end

    def succeeded(delivery, status)
      delivery.update!(status: "delivered", attempts: delivery.attempts + 1, response_status: status, error: nil,
                       delivered_at: Time.current, next_attempt_at: nil)
      delivery.webhook.update!(consecutive_failures: 0) unless delivery.event == TEST_EVENT
      delivery
    end

    def failed(delivery, status, error)
      test = delivery.event == TEST_EVENT
      attempts = delivery.attempts + 1
      retry_in = !test && attempts < MAX_ATTEMPTS ? BACKOFF[attempts - 1] : nil
      delivery.update!(status: retry_in ? "pending" : "failed", attempts:, response_status: status, error: error.to_s.truncate(250),
                       next_attempt_at: retry_in&.from_now)
      return delivery if test

      Jobs::DeliverWebhook.set(wait: retry_in).perform_later(delivery.id) if retry_in
      count_failure(delivery.webhook)
      delivery
    end

    def count_failure(webhook)
      webhook.increment!(:consecutive_failures)
      return unless webhook.enabled? && webhook.consecutive_failures >= DISABLE_AFTER

      webhook.update!(enabled: false, disabled_at: Time.current, disabled_reason: "#{DISABLE_AFTER} deliveries failed in a row")
      dropped_pending(webhook)
      ::User.all.select { |user| Access.can?(user, MANAGE_ABILITY) }.each do |user|
        Records::Notification.notify(user.id, "webhook.disabled", subject: webhook, title: webhook.name, webhook: webhook.id)
      end
    end

    def dropped_pending(webhook)
      webhook.deliveries.where(status: "pending").update_all(status: "failed", next_attempt_at: nil, error: "the webhook was disabled")
    end
  end
end
