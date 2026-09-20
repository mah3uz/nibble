module Nibble
  module Records
    class OutboxEvent < ::ApplicationRecord
      self.table_name = "events_outbox"

      scope :pending, -> { where(dispatched_at: nil) }
    end
  end
end
