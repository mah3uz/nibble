module Nibble
  module Records
    # Settings a person changes in the Control Plane, as against config/nibble.yml, which a person edits by hand.
    class Setting < ::ApplicationRecord
      def self.read(key, default = nil)
        where(key: key.to_s).pick(:value).then { |value| value.nil? ? default : value }
      end

      def self.write(key, value)
        upsert({ key: key.to_s, value:, created_at: Time.current, updated_at: Time.current }, unique_by: :key)
        value
      end
    end
  end
end
