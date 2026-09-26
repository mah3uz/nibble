module Nibble
  class Session < Nibble::ApplicationRecord
    self.table_name = "nibble_sessions"

    belongs_to :user

    before_create { self.elevated_at ||= Time.current }
  end
end
