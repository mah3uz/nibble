module Nibble
  module Records
    class OutboundRequest < Nibble::ApplicationRecord
      self.table_name = "outbound_requests"
      include TypedPolymorphism

      belongs_to :owner, polymorphic: true, optional: true

      scope :recent, -> { order(created_at: :desc) }
    end
  end
end
