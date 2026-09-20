require "test_helper"
require "webmock"

class Nibble::WebhooksTest < ActiveSupport::TestCase
  include NibbleRecordsHelper
  include ActiveJob::TestHelper
  include WebMock::API

  HOOK = "https://hooks.example.test/nibble".freeze
  Delivery = Nibble::Records::WebhookDelivery

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!
    @resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
  end

  teardown do
    Nibble::Outbound::Guard.resolver = @resolver
    WebMock.reset!
    WebMock.disable!
  end

  def webhook(**attrs)
    Nibble::Records::Webhook.new(name: "Site", url: HOOK, events: [ "record.published" ], **attrs).tap do |hook|
      hook.secret = "whsec_test"
      hook.save!
    end
  end

  def publish_article(title = "Hello")
    article = create_entry("articles", { "title" => title })
    assert lifecycle(article, :publish, { "published_at" => 1.hour.ago.iso8601 }).ok?
    Nibble::Events.dispatch_pending
    article
  end

  test "a published entry reaches a subscribed webhook as signed JSON the receiver can verify, without the editor's IP" do
    webhook
    stub_request(:post, HOOK).to_return(status: 204)

    article = publish_article
    perform_enqueued_jobs(only: Nibble::Jobs::DeliverWebhook)

    assert_requested(:post, HOOK) do |request|
      timestamp, signature = request.headers["X-Nibble-Signature"].scan(/t=(\d+),v1=(\h+)/).first
      body = JSON.parse(request.body)
      assert_equal OpenSSL::HMAC.hexdigest("SHA256", "whsec_test", "#{timestamp}.#{request.body}"), signature
      assert_equal [ "record.published", article.id ], [ body["event"], body.dig("data", "id") ]
      assert_match(/\Aevt_\d+\z/, body["id"])
      assert_not body["data"].key?("ip"), "the editor's IP address stays on this server"
      assert_not body["data"].key?("outbox_id")
    end
    assert_equal [ "delivered", 1 ], Delivery.sole.values_at(:status, :attempts)
  end

  test "only enabled webhooks subscribed to the event, and to the entry's collection when filtered, get a delivery" do
    matching = webhook(collections: [ "articles" ])
    webhook(name: "Docs only", collections: [ "docs" ])
    webhook(name: "Saves only", events: [ "record.saved" ])
    webhook(name: "Everything", events: [ "record.*" ], enabled: false)

    publish_article
    assert_equal [ matching.id ], Delivery.distinct.pluck(:webhook_id)
  end

  test "a failing receiver is retried on the backoff schedule, then the delivery is given up" do
    webhook
    stub_request(:post, HOOK).to_return(status: 500)
    publish_article
    delivery = Delivery.sole

    freeze_time do
      Nibble::Webhooks.deliver(delivery)
      assert_equal [ "pending", 1, 1.minute.from_now ], delivery.reload.values_at(:status, :attempts, :next_attempt_at)
      assert_enqueued_with(job: Nibble::Jobs::DeliverWebhook, args: [ delivery.id ], at: 1.minute.from_now)
    end

    (Nibble::Webhooks::MAX_ATTEMPTS - 1).times { Nibble::Webhooks.deliver(delivery.reload) }
    assert_equal [ "failed", 8, nil ], delivery.reload.values_at(:status, :attempts, :next_attempt_at)
  end

  test "after 20 failures in a row a webhook turns itself off, stops its queued retries and tells the admins" do
    hook = webhook
    stub_request(:post, HOOK).to_return(status: 503)
    publish_article
    hook.update!(consecutive_failures: Nibble::Webhooks::DISABLE_AFTER - 1)

    Nibble::Webhooks.deliver(Delivery.sole)
    hook.reload
    assert_not hook.enabled?
    assert_equal "failed", Delivery.sole.status, "nothing keeps retrying against a webhook that's off"
    assert_equal [ users(:admin).id ], Nibble::Records::Notification.where(kind: "webhook.disabled").pluck(:user_id)

    publish_article("Another")
    assert_equal 1, Delivery.count
  end

  test "one success resets the failure count" do
    hook = webhook(consecutive_failures: 5)
    stub_request(:post, HOOK).to_return(status: 200)
    publish_article
    Nibble::Webhooks.deliver(Delivery.sole)
    assert_equal 0, hook.reload.consecutive_failures
  end

  test "a resend is a new delivery of the same event, so the receiver can recognise the duplicate" do
    webhook
    stub_request(:post, HOOK).to_return(status: 200)
    publish_article
    original = Delivery.sole

    resent = Nibble::Webhooks.resend(original)
    perform_enqueued_jobs(only: Nibble::Jobs::DeliverWebhook)
    ids = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.map { |signature| JSON.parse(signature.body)["id"] }.uniq
    assert_not_equal original.id, resent.id
    assert_equal 1, ids.size
  end

  test "a URL that points inside the network is refused, and the reason is kept on the delivery" do
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "10.0.0.5" ] }
    hook = webhook

    delivery = Nibble::Webhooks.test(hook)
    assert_equal "failed", delivery.status
    assert_match "private or reserved address", delivery.error
    assert_equal 0, hook.reload.consecutive_failures, "test pings never count towards turning a webhook off"
  end

  test "delivery logs older than 30 days are purged with their request logs" do
    webhook
    stub_request(:post, HOOK).to_return(status: 200)
    publish_article
    Nibble::Webhooks.deliver(Delivery.sole)
    Delivery.sole.update_columns(created_at: 31.days.ago)

    Nibble::Jobs::PurgeWebhookDeliveries.perform_now
    assert_empty Delivery.all
    assert_empty Nibble::Records::OutboundRequest.where(purpose: "webhook")
  end
end
