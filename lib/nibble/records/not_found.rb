module Nibble
  module Records
    class NotFound < ::ApplicationRecord
      self.table_name = "not_found_log"

      MAX_PATH = 2048

      def self.record(path, referrer: nil, now: Time.current)
        return if path.length > MAX_PATH

        upsert({ path:, hits: 1, first_seen_at: now, last_seen_at: now, referrer: referrer&.first(MAX_PATH) },
          unique_by: :path, on_duplicate: Arel.sql("hits = not_found_log.hits + 1, last_seen_at = excluded.last_seen_at, referrer = COALESCE(excluded.referrer, not_found_log.referrer)"))
      end
    end
  end
end
