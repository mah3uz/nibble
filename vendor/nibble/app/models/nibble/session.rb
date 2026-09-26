module Nibble
  class Session < Nibble::ApplicationRecord
    self.table_name = "nibble_sessions"

    belongs_to :user

    # Writes are spaced out, so a busy screen doesn't write on every request; the expiry is minutes, not seconds.
    TOUCH_EVERY = 10.seconds

    before_create do
      self.elevated_at ||= Time.current
      self.last_active_at ||= Time.current
    end

    def expires_at = (last_active_at || created_at) + Nibble.config.session_idle

    def expired? = expires_at <= Time.current

    def remaining = [ (expires_at - Time.current).ceil, 0 ].max

    def active!
      update_column(:last_active_at, Time.current) if last_active_at.nil? || last_active_at < TOUCH_EVERY.ago
    end
  end
end
