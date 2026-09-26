module Nibble
  module Records
    class AuditEntry < Nibble::ApplicationRecord
      self.table_name = "audit_log"

      before_update { raise ActiveRecord::ReadOnlyRecord, "audit entries are append-only" }
      before_destroy { raise ActiveRecord::ReadOnlyRecord, "audit entries are append-only" }
    end
  end
end
