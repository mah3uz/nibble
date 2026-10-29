module Nibble
  module Forms
    module Audit
      def self.record(action, user:, ip: nil, subject: nil, **changeset)
        Records::AuditEntry.create!(action:, actor_type: "user", actor_id: user.id, subject_type: subject&.record_type,
          subject_id: subject&.id, changeset: changeset.stringify_keys, ip:, created_at: Time.current)
      end
    end
  end
end
