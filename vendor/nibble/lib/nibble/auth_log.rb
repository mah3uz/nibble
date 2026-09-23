module Nibble
  module AuthLog
    module_function

    def record(action, user: nil, ip: nil, **changes)
      Records::AuditEntry.create!(
        action: "auth.#{action}", actor_type: user && "user", actor_id: user&.id,
        subject_type: user && "user", subject_id: user&.id,
        changeset: changes.deep_stringify_keys, ip:, created_at: Time.current
      )
    end
  end
end
