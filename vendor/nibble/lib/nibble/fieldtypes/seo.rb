module Nibble
  module Fieldtypes
    class Seo < Fieldtype
      SCHEMA_TYPES = %w[WebPage Article BlogPosting FAQPage Organization LocalBusiness Product Event].freeze
      KEYS = %w[title exact_title description canonical og_image noindex nositemap schema_type json_ld_overrides].freeze
      FLAGS = %w[exact_title noindex nositemap].freeze
      IMAGE_TYPES = %w[jpg jpeg png webp gif avif].freeze
      ImageField = Data.define(:config, :value)

      self.categories = %w[special]
      self.contract_samples = [ { "title" => "Title", "noindex" => true }, nil ]
      self.selectable_in_forms = false
      self.config_field_items = {
        "title_limit" => { "type" => "integer", "default" => 60, "width" => 50 },
        "description_limit" => { "type" => "integer", "default" => 160, "width" => 50 },
        "schema_types" => { "type" => "list", "default" => SCHEMA_TYPES }
      }

      def default_value = {}

      def pre_process(value)
        value = value.to_h.stringify_keys
        KEYS.index_with { |key| value[key] }.merge(flags(value)).merge("og_image" => image(value).pre_process(value["og_image"]).find { |item| item["asset"].present? })
      end

      def process(value)
        value = value.to_h.stringify_keys.slice(*KEYS)
        value.merge!(flags(value)).merge!("og_image" => image(value).process(value["og_image"]))
        value.compact_blank.presence
      end

      def extra_rules(root_values: nil, prefix: "", replacements: {})
        entry = ->(rules, attribute) { Validator::Entry.new(rules: rules.map { |rule| Validation.parse(rule) }, attribute:) }
        {
          "#{prefix}title" => entry.([ "string" ], "SEO title"),
          "#{prefix}description" => entry.([ "string" ], "Meta description"),
          "#{prefix}og_image" => entry.([ "records_exist:#{image.scope_param}" ], "Share image"),
          "#{prefix}canonical" => entry.([ 'regex:/^(https:\/\/\S+|\/\S*)$/' ], "Canonical URL"),
          "#{prefix}schema_type" => entry.([ "in:#{config('schema_types').join(',')}" ], "Schema type"),
          "#{prefix}json_ld_overrides" => entry.([ "array" ], "JSON-LD overrides")
        }
      end

      def augment(value)
        value = value.to_h.stringify_keys
        pre_process(value).merge("og_image" => image(value).augment(value["og_image"]))
      end

      def preload = { "data" => image(field&.value.to_h.stringify_keys).preload["data"] }
      def export(value, ctx = nil) = transfer(value, ctx, :export)
      def import(value, ctx = nil) = transfer(value, ctx, :import)
      def relations(value) = image(value.to_h.stringify_keys).relations(value.to_h.stringify_keys["og_image"])
      def dependencies(value) = image(value.to_h.stringify_keys).dependencies(value.to_h.stringify_keys["og_image"])
      def ts_type = "{ title: string | null; exact_title: boolean; description: string | null; canonical: string | null; og_image: AssetValue | null; noindex: boolean; nositemap: boolean; schema_type: string | null; json_ld_overrides: Record<string, unknown> | null }"

      private

      def flags(value) = FLAGS.index_with { |key| [ true, "1", "true" ].include?(value[key]) }

      def image(value = {})
        Assets.new(ImageField.new(config: { "max_files" => 1, "alt" => "none", "allowed_types" => IMAGE_TYPES }, value: value["og_image"]))
      end

      def transfer(value, ctx, direction)
        return value unless ctx && value.is_a?(Hash)

        image = image(value)
        moved = image.public_send(direction, value["og_image"], ctx)
        value.merge("og_image" => moved).compact
      end
    end
  end
end
