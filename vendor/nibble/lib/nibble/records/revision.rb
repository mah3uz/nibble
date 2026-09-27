module Nibble
  module Records
    class Revision < Nibble::ApplicationRecord
      self.table_name = "revisions"
      include TypedPolymorphism

      KINDS = %w[save publish restore import].freeze

      belongs_to :record, polymorphic: true
      belongs_to :actor, class_name: "Nibble::User", optional: true
      belongs_to :grant, class_name: "Nibble::Grant", optional: true

      validates :kind, inclusion: { in: KINDS }
    end
  end
end
