module Nibble
  module Jobs
    class PurgeWebhookDeliveries < Nibble::ApplicationJob
      queue_as :maintenance

      def perform
        Records::WebhookDelivery.where(created_at: ...Webhooks::RETENTION.ago).find_each(&:destroy!)
      end
    end
  end
end
