module Nibble
  module Records
    class OutboxEvent < Nibble::ApplicationRecord
      self.table_name = "events_outbox"

      scope :pending, -> { where(dispatched_at: nil) }
    end
  end
end
