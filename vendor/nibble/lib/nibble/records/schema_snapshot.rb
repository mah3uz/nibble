module Nibble
  module Records
    class SchemaSnapshot < ::ApplicationRecord
      self.table_name = "schema_snapshots"

      def self.latest = order(:id).last
    end
  end
end
