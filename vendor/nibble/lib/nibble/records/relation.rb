module Nibble
  module Records
    class Relation < ::ApplicationRecord
      self.table_name = "relations"
      include TypedPolymorphism

      belongs_to :source, polymorphic: true
    end
  end
end
