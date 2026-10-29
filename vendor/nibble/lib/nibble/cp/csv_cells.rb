module Nibble
  module Cp
    module CsvCells
      FORMULA = /\A[=+\-@\t\r]/
      NUMBER = /\A-?\d+(?:\.\d+)?\z/

      module_function

      def row(values) = values.map { |value| cell(value) }

      # A spreadsheet runs a cell that starts like a formula; the quote makes it text.
      def cell(value) = value.is_a?(String) && value.match?(FORMULA) && !value.match?(NUMBER) ? "'#{value}" : value
    end
  end
end
