module Nibble
  module Records
    class WorkflowTransition < ::ApplicationRecord
      self.table_name = "workflow_transitions"
      include TypedPolymorphism

      belongs_to :record, polymorphic: true
      belongs_to :actor, class_name: "::User", optional: true
    end
  end
end
