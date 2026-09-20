module Nibble
  module Fieldtypes
    class List < Fieldtype
      self.categories = %w[structured]
      self.contract_samples = [ %w[a b] ]
      self.config_field_items = { "add_row" => { "type" => "text" } }

      def pre_process(value) = value.nil? ? [] : Array(value)

      def process(value)
        return value unless value.is_a?(Array)

        value.reject { |item| item.nil? || item == "" }.map do |item|
          next item unless item.is_a?(String) && item.match?(/\A-?\d+(\.\d+)?\z/)

          item.include?(".") ? item.to_f : item.to_i
        end
      end

      def search_text(value) = Array(value).join(" ").presence
      def ts_type = "string[]"
    end
  end
end
