module Nibble
  module Records
    class Draft < ::ApplicationRecord
      self.table_name = "drafts"
      include TypedPolymorphism

      belongs_to :record, polymorphic: true
      belongs_to :author, class_name: "::User", optional: true
    end
  end
end
