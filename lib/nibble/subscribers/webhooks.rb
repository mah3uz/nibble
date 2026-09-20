module Nibble
  module Subscribers
    module Webhooks
      def self.call(name, payload)
        return if payload["mode"] == "import"

        event_id = payload["outbox_id"]
        Records::Webhook.enabled.find_each do |webhook|
          Nibble::Webhooks.enqueue(webhook, name, payload.except("outbox_id"), event_id:) if webhook.subscribed?(name, payload)
        end
      end
    end
  end
end
