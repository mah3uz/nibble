module Nibble
  module Fieldtypes
    class Terms < Relationship
      self.selectable = true
      self.contract_samples = [ %w[t1], nil ]
      self.keywords = %w[relationship taxonomy tags categories]
      self.config_field_items = [
        { "display" => "Input Behavior", "fields" => {
          "taxonomies" => { "type" => "list", "default" => [] },
          "mode" => { "type" => "select", "default" => "default", "options" => %w[default select typeahead], "width" => 50 },
          "create" => { "type" => "toggle", "default" => true, "width" => 50 }
        } },
        { "display" => "Boundaries & Limits", "fields" => { "max_items" => { "type" => "integer" } } }
      ]

      def self.resolver_type = "term"

      def scope = { "taxonomies" => config("taxonomies") }
      def ts_type = single? ? "TermSummary | null" : "TermSummary[]"
    end
  end
end
