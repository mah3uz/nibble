module Nibble
  module Records
    class Relation < Nibble::ApplicationRecord
      self.table_name = "relations"
      include TypedPolymorphism

      belongs_to :source, polymorphic: true
    end
  end
end
