module Nibble
  module Fieldtypes
    class Assets < Relationship
      ALT_MODES = %w[optional required none].freeze

      self.selectable = true
      self.contract_samples = [ [ { "asset" => "a1", "alt" => "Alt" } ], nil ]
      self.categories = %w[media relationship]
      self.keywords = %w[image images file files upload media]
      self.config_field_items = [
        { "display" => "Input Behavior", "fields" => {
          "folder" => { "type" => "text", "width" => 50 },
          "restrict" => { "type" => "toggle", "default" => false, "width" => 50 },
          "allow_uploads" => { "type" => "toggle", "default" => true, "width" => 50 },
          "mode" => { "type" => "select", "default" => "grid", "options" => %w[grid list], "width" => 50 },
          "alt" => { "type" => "select", "default" => "optional", "options" => ALT_MODES, "width" => 50 },
          "preset" => { "type" => "text", "width" => 50 }
        } },
        { "display" => "Boundaries & Limits", "fields" => {
          "min_files" => { "type" => "integer", "width" => 50 },
          "max_files" => { "type" => "integer", "width" => 50 },
          "allowed_types" => { "type" => "list", "default" => [] }
        } }
      ]

      def self.resolver_type = "asset"

      def single? = config("max_files").to_i == 1

      def pre_process(value) = items(value)

      def process(value)
        stored = items(value).map { |item| item.slice("asset", "alt").compact_blank }.select { |item| item["asset"].present? }
        return nil if stored.empty?

        single? ? stored.first : stored
      end

      def pre_process_validatable(value) = items(value).select { |item| item["asset"].present? }

      def rules
        [
          "array",
          *("min:#{config('min_files')}" if config("min_files").to_i.positive?),
          *("max:#{config('max_files')}" if config("max_files").to_i.positive?),
          "records_exist:#{scope_param}"
        ]
      end

      def extra_rules(root_values: nil, prefix: "", replacements: {})
        return {} unless config("alt") == "required"

        items(field&.value).each_index.to_h do |index|
          [ "#{prefix}#{index}.alt", Validator::Entry.new(rules: [ Validation.parse("required") ], attribute: "Alt text") ]
        end
      end

      def augment(value)
        list = items(value)
        found = find(list.map { |item| item["asset"] }).index_by { |asset| asset["id"] }
        presented = list.filter_map do |item|
          asset = found[item["asset"]] or next
          asset.merge("alt" => item["alt"].presence || asset["alt"])
        end
        single? ? presented.first : presented
      end

      def preload = { "data" => find(items(field&.value).map { |item| item["asset"] }), "max_files" => config("max_files"), "mode" => config("mode") }

      def pre_process_index(value) = find(items(value).map { |item| item["asset"] }).map { |asset| asset.slice("id", "title", "url", "thumbnail") }
      def export(value, ctx = nil) = transfer(value, ctx) { |item, key| item["alt"].present? ? { "asset" => key, "alt" => item["alt"] } : key }
      def import(value, ctx = nil) = transfer(value, ctx) { |item, id| { "asset" => id, "alt" => item["alt"] }.compact_blank }
      def relations(value) = items(value).map { |item| [ "asset", item["asset"] ] }
      def dependencies(value) = items(value).map { |item| "asset:#{item['asset']}" }
      def scope = { "folder" => (config("folder") if config("restrict")), "allowed_types" => config("allowed_types"), "preset" => config("preset") }
      def ts_type = single? ? "AssetValue | null" : "AssetValue[]"

      private

      def transfer(value, ctx)
        return value unless ctx

        moved = items(value).filter_map do |item|
          reference = ctx.resolve("asset", item["asset"]) if item["asset"].present?
          yield(item, reference) if reference
        end
        single? ? moved.first : moved
      end

      def items(value)
        list = value.is_a?(Hash) ? [ value ] : Array(value)
        list.map { |item| item.is_a?(Hash) ? item.stringify_keys.slice("asset", "alt") : { "asset" => item.to_s, "alt" => nil } }
      end
    end
  end
end
