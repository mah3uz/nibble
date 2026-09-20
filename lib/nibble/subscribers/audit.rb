module Nibble
  module Subscribers
    module Audit
      def self.call(name, payload)
        Records::AuditEntry.create!(
          actor_type: payload.dig("actor", "type"), actor_id: payload.dig("actor", "id"), action: name,
          subject_type: payload["type"], subject_id: payload["id"], changeset: payload["changes"].to_h, ip: payload["ip"],
          created_at: Time.current
        )
      end
    end
  end
end
