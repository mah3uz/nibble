module Nibble
  module Fieldtypes
    class AnalyticsTags < Fieldtype
      self.title = "Analytics tags"
      self.categories = %w[special]
      self.selectable = false
      self.validatable = false
      self.defaultable = false
      self.localizable = false

      def process(_value) = nil
      def augment(_value) = nil
      def ts_type = "null"
    end
  end
end
