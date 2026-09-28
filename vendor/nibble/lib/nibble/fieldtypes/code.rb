module Nibble
  module Fieldtypes
    class Code < Fieldtype
      self.categories = %w[text]
      self.contract_samples = [ "<script src=\"https://example.com/widget.js\"></script>" ]
      self.keywords = %w[html snippet embed script]
      self.config_field_items = [
        { "display" => "Appearance", "fields" => { "placeholder" => { "type" => "text" } } }
      ]

      def ts_type = "string | null"
    end
  end
end
