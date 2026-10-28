module Nibble
  module Records
    class ScheduledTask < Nibble::ApplicationRecord
      self.table_name = "scheduled_tasks"
    end
  end
end
