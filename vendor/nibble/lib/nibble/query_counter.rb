module Nibble
  module QueryCounter
    IGNORED = %w[SCHEMA TRANSACTION].freeze

    def self.count
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:cached] || IGNORED.include?(payload[:name]) }
      result = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      [ result, queries ]
    end
  end
end
