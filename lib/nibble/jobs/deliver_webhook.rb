module Nibble
  module Jobs
    class DeliverWebhook < ::ApplicationJob
      queue_as :deliveries

      def perform(delivery_id)
        delivery = Records::WebhookDelivery.find_by(id: delivery_id) or return
        return unless delivery.status == "pending" && delivery.webhook.enabled?

        Webhooks.deliver(delivery)
      end
    end
  end
end
