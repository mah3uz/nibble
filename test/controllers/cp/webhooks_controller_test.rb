require "test_helper"
require "webmock"

class Nibble::Cp::WebhooksControllerTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper
  include WebMock::API

  HOOK = "https://hooks.example.test/nibble".freeze
  Webhook = Nibble::Records::Webhook

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: true)
    @resolver = Nibble::Outbound::Guard.resolver
    Nibble::Outbound::Guard.resolver = ->(_host) { [ "93.184.216.34" ] }
    sign_in_as users(:admin)
  end

  teardown do
    Nibble::Outbound::Guard.resolver = @resolver
    WebMock.reset!
    WebMock.disable!
  end

  def props = JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["props"]
  def create_webhook(**attrs) = post("/cp/webhooks", params: { webhook: { name: "Site", url: HOOK, events: [ "record.published" ], enabled: true }.merge(attrs) })

  test "only admins manage webhooks, because they send content to other systems" do
    sign_in_as users(:editor)
    get "/cp/webhooks"
    assert_response :forbidden
    create_webhook
    assert_response :forbidden
    assert_empty Webhook.all
  end

  test "creating a webhook gives it its own signing secret; bad input comes back on the fields" do
    create_webhook(url: "ftp://nope", events: [ "record.exploded" ])
    assert_empty Webhook.all
    follow_redirect!
    assert_equal %w[events url], props["errors"].keys.sort

    create_webhook
    webhook = Webhook.sole
    assert_redirected_to "/cp/webhooks/#{webhook.id}/edit"
    assert_match(/\Awhsec_\h{48}\z/, webhook.secret)
    assert_not_includes webhook.secret_ciphertext, webhook.secret, "the secret is encrypted at rest"
  end

  test "a test ping reports the receiver's answer straight away" do
    create_webhook
    webhook = Webhook.sole
    stub_request(:post, HOOK).to_return(status: 200)

    post "/cp/webhooks/#{webhook.id}/test"
    assert_equal "Test delivered (HTTP 200).", flash[:notice]

    stub_request(:post, HOOK).to_return(status: 410)
    post "/cp/webhooks/#{webhook.id}/test"
    assert_equal "Test failed: HTTP 410", flash[:alert]

    get "/cp/webhooks/#{webhook.id}/edit"
    assert_equal %w[failed delivered], props["deliveries"].map { |delivery| delivery["status"] }
    assert_includes props["deliveries"].first["request_body"], "webhook.test"
  end

  test "a webhook that turned itself off can be turned back on, with its failure count cleared" do
    create_webhook
    webhook = Webhook.sole
    webhook.update!(enabled: false, consecutive_failures: 20, disabled_at: Time.current, disabled_reason: "20 deliveries failed in a row")

    post "/cp/webhooks/#{webhook.id}/enable"
    assert_equal [ true, 0, nil ], webhook.reload.values_at(:enabled, :consecutive_failures, :disabled_reason)
  end

  test "a new secret replaces the old one, and a delivery can be resent" do
    create_webhook
    webhook = Webhook.sole
    old = webhook.secret
    post "/cp/webhooks/#{webhook.id}/roll_secret"
    assert_not_equal old, webhook.reload.secret

    delivery = webhook.deliveries.create!(event: "record.published", event_id: 9, payload: { "id" => 1 }, status: "failed", attempts: 8)
    assert_enqueued_with(job: Nibble::Jobs::DeliverWebhook) { post "/cp/webhooks/#{webhook.id}/deliveries/#{delivery.id}/resend" }
    assert_equal [ 9, 9 ], webhook.deliveries.pluck(:event_id)
  end

  test "deleting a webhook deletes its deliveries" do
    create_webhook
    webhook = Webhook.sole
    webhook.deliveries.create!(event: "record.published", payload: {})

    delete "/cp/webhooks/#{webhook.id}"
    assert_empty Webhook.all
    assert_empty Nibble::Records::WebhookDelivery.all
  end
end
