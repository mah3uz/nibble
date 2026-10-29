module Nibble
  module Fieldtypes
    class Terms < Relationship
      self.selectable = true
      self.contract_samples = [ %w[t1], nil ]
      self.keywords = %w[relationship taxonomy tags categories]
      self.config_field_items = [
        { "display" => "Input behavior", "fields" => {
          "taxonomies" => { "type" => "list", "default" => [] },
          "mode" => { "type" => "select", "default" => "auto", "options" => %w[auto default select typeahead stack], "width" => 50 },
          "create" => { "type" => "toggle", "default" => true, "width" => 50 }
        } },
        { "display" => "Boundaries and limits", "fields" => { "max_items" => { "type" => "integer" } } }
      ]

      def self.resolver_type = "term"

      def creatable
        wanted = Array(config("taxonomies")).compact_blank
        Nibble.schema.taxonomies.filter_map do |item|
          next if wanted.any? && wanted.exclude?(item.handle)
          next unless Access.can?(Current.user, "terms.#{item.handle}.create")

          { "handle" => item.handle, "label" => item["title"].to_s.singularize,
            "fields" => self.class.dialog_fields(Records::Term.new(taxonomy: item.handle, blueprint: Array(item["blueprints"]).first)) }
        end
      end

      def scope = { "taxonomies" => config("taxonomies") }
      def ts_type = single? ? "TermSummary | null" : "TermSummary[]"
    end
  end
end
