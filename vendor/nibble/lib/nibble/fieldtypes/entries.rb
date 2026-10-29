module Nibble
  module Fieldtypes
    class Entries < Relationship
      self.selectable = true
      self.contract_samples = [ %w[1 2], nil ]
      self.keywords = %w[relationship related entry]
      self.config_field_items = [
        { "display" => "Input behavior", "fields" => {
          "collections" => { "type" => "list", "default" => [] },
          "mode" => { "type" => "select", "default" => "auto", "options" => %w[auto default select typeahead stack], "width" => 50 },
          "create" => { "type" => "toggle", "default" => true, "width" => 50 }
        } },
        { "display" => "Boundaries and limits", "fields" => { "max_items" => { "type" => "integer" } } }
      ]

      def self.resolver_type = "entry"

      def creatable
        wanted = Array(config("collections")).compact_blank
        Nibble.schema.collections.filter_map do |item|
          next if (wanted.any? && wanted.exclude?(item.handle)) || item["files"].present?
          next unless Access.can?(Current.user, "entries.#{item.handle}.create")

          self.class.dialog_target(item.handle, item["title"].to_s.singularize, Records::Entry.new(collection: item.handle, blueprint: Array(item["blueprints"]).first))
        end
      end

      def scope = { "collections" => config("collections") }
      def ts_type = single? ? "EntrySummary | null" : "EntrySummary[]"
    end
  end
end
