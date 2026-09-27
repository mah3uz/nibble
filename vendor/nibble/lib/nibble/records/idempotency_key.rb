module Nibble
  module Records
    # The first answer to a write sent with an idempotency key, so a retried request gets it back instead of repeating.
    class IdempotencyKey < Nibble::ApplicationRecord
      KEEP = 1.day
    end
  end
end
