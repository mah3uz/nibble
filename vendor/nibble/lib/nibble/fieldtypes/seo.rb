module Nibble
  module Fieldtypes
    class Seo < Fieldtype
      SCHEMA_TYPES = %w[WebPage Article BlogPosting FAQPage Organization LocalBusiness Product Event].freeze
      KEYS = %w[title description canonical og_image noindex schema_type json_ld_overrides].freeze

      self.categories = %w[special]
      self.contract_samples = [ { "title" => "Title", "noindex" => true }, nil ]
      self.selectable_in_forms = false
      self.config_field_items = {
        "title_limit" => { "type" => "integer", "default" => 60, "width" => 50 },
        "description_limit" => { "type" => "integer", "default" => 160, "width" => 50 },
        "schema_types" => { "type" => "list", "default" => SCHEMA_TYPES }
      }

      def default_value = {}

      def pre_process(value) = KEYS.index_with { |key| value.to_h.stringify_keys[key] }.merge("noindex" => value.to_h.stringify_keys["noindex"] == true)

      def process(value)
        value = value.to_h.stringify_keys.slice(*KEYS)
        value["noindex"] = value["noindex"] == true || value["noindex"] == "1" || value["noindex"] == "true"
        value.compact_blank.presence
      end

      def extra_rules(root_values: nil, prefix: "", replacements: {})
        entry = ->(rules, attribute) { Validator::Entry.new(rules: rules.map { |rule| Validation.parse(rule) }, attribute:) }
        {
          "#{prefix}title" => entry.([ "string" ], "SEO title"),
          "#{prefix}description" => entry.([ "string" ], "Meta description"),
          "#{prefix}canonical" => entry.([ 'regex:/^(https:\/\/\S+|\/\S*)$/' ], "Canonical URL"),
          "#{prefix}schema_type" => entry.([ "in:#{config('schema_types').join(',')}" ], "Schema type"),
          "#{prefix}json_ld_overrides" => entry.([ "array" ], "JSON-LD overrides")
        }
      end

      def augment(value) = pre_process(value)
      def ts_type = "{ title: string | null; description: string | null; canonical: string | null; og_image: string | null; noindex: boolean; schema_type: string | null; json_ld_overrides: Record<string, unknown> | null }"
    end
  end
end
