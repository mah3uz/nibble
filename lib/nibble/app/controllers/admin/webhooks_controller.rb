module Admin
  class WebhooksController < BaseController
    DELIVERIES_SHOWN = 50

    before_action { authorize!(Nibble::Webhooks::MANAGE_ABILITY) }
    before_action :find_webhook, except: %i[index new create]

    def index
      last = Nibble::Records::WebhookDelivery.where(id: Nibble::Records::WebhookDelivery.group(:webhook_id).select("MAX(id)")).index_by(&:webhook_id)
      render inertia: "admin/webhooks/Index", props: {
        webhooks: Nibble::Records::Webhook.order(:name).map do |webhook|
          delivery = last[webhook.id]
          { id: webhook.id, name: webhook.name, url: webhook.url, events: webhook.events, enabled: webhook.enabled,
            disabled_reason: webhook.disabled_reason, edit_url: "/admin/webhooks/#{webhook.id}/edit",
            last_delivery: delivery && { status: delivery.status, at: delivery.updated_at.utc.iso8601 } }
        end
      }
    end

    def new = render_form(Nibble::Records::Webhook.new(enabled: true, events: [], collections: []))
    def edit = render_form(@webhook)

    def create
      webhook = Nibble::Records::Webhook.new(webhook_params)
      webhook.secret = Nibble::Records::Webhook.generate_secret
      return redirect_to("/admin/webhooks/new", inertia: { errors: errors_for(webhook) }) unless webhook.save

      redirect_to "/admin/webhooks/#{webhook.id}/edit", notice: "Webhook created. Copy its signing secret to verify deliveries."
    end

    def update
      return redirect_to("/admin/webhooks/#{@webhook.id}/edit", inertia: { errors: errors_for(@webhook) }) unless @webhook.update(webhook_params)

      redirect_to "/admin/webhooks/#{@webhook.id}/edit", notice: "Webhook saved."
    end

    def destroy
      @webhook.destroy!
      redirect_to "/admin/webhooks", notice: "Webhook deleted."
    end

    def test
      delivery = Nibble::Webhooks.test(@webhook)
      flash = delivery.status == "delivered" ? { notice: "Test delivered (HTTP #{delivery.response_status})." } : { alert: "Test failed: #{delivery.error}" }
      redirect_to "/admin/webhooks/#{@webhook.id}/edit", **flash
    end

    def enable
      @webhook.update!(enabled: true, consecutive_failures: 0, disabled_at: nil, disabled_reason: nil)
      redirect_to "/admin/webhooks/#{@webhook.id}/edit", notice: "Webhook turned back on."
    end

    def roll_secret
      @webhook.update!(secret: Nibble::Records::Webhook.generate_secret)
      redirect_to "/admin/webhooks/#{@webhook.id}/edit", notice: "New signing secret created. Update your receiver to use it."
    end

    def resend
      delivery = @webhook.deliveries.find(params[:delivery_id])
      Nibble::Webhooks.resend(delivery)
      redirect_to "/admin/webhooks/#{@webhook.id}/edit", notice: "Delivery queued to resend."
    end

    private

    def find_webhook = @webhook = Nibble::Records::Webhook.find(params[:id])

    def webhook_params
      permitted = params.require(:webhook).permit(:name, :url, :enabled, events: [], collections: [])
      permitted.merge(events: Array(permitted[:events]).compact_blank, collections: Array(permitted[:collections]).compact_blank)
    end

    def errors_for(webhook) = webhook.errors.to_hash.transform_values(&:first)

    def render_form(webhook)
      render inertia: "admin/webhooks/Edit", props: {
        webhook: webhook.persisted? ? webhook_props(webhook) : { id: nil, name: "", url: "", events: [], collections: [], enabled: true },
        events: Nibble::Webhooks::EVENTS.map { |value, label| { value:, label: } },
        collections: Nibble.schema.collections.map { |collection| { value: collection.handle, label: collection["title"] } },
        deliveries: webhook.persisted? ? webhook.deliveries.order(id: :desc).limit(DELIVERIES_SHOWN).map { |delivery| delivery_props(delivery) } : []
      }
    end

    def webhook_props(webhook)
      webhook.slice(:id, :name, :url, :events, :collections, :enabled, :disabled_reason, :consecutive_failures)
        .merge(secret: webhook.secret, disabled_at: webhook.disabled_at&.utc&.iso8601)
    end

    def delivery_props(delivery)
      log = delivery.outbound_requests.order(created_at: :desc).first
      { id: delivery.id, event: delivery.event, status: delivery.status, attempts: delivery.attempts,
        response_status: delivery.response_status, error: delivery.error, created_at: delivery.created_at.utc.iso8601,
        next_attempt_at: delivery.next_attempt_at&.utc&.iso8601, request_body: log&.request_body, response_body: log&.response_body,
        duration_ms: log&.duration_ms }
    end
  end
end
