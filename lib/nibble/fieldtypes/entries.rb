module Nibble
  module Fieldtypes
    class Entries < Relationship
      self.selectable = true
      self.contract_samples = [ %w[1 2], nil ]
      self.keywords = %w[relationship related entry]
      self.config_field_items = [
        { "display" => "Input Behavior", "fields" => {
          "collections" => { "type" => "list", "default" => [] },
          "mode" => { "type" => "select", "default" => "default", "options" => %w[default select typeahead], "width" => 50 },
          "create" => { "type" => "toggle", "default" => true, "width" => 50 }
        } },
        { "display" => "Boundaries & Limits", "fields" => { "max_items" => { "type" => "integer" } } }
      ]

      def self.resolver_type = "entry"

      def scope = { "collections" => config("collections") }
      def ts_type = single? ? "EntrySummary | null" : "EntrySummary[]"
    end
  end
end
