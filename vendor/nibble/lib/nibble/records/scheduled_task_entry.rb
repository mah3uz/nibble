module Nibble
  module Records
    # The entries a task's import created, by the key the feed gives them: the only entries a task ever changes.
    class ScheduledTaskEntry < Nibble::ApplicationRecord
      self.table_name = "scheduled_task_entries"
    end
  end
end
