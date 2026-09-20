module Nibble
  class Schema
    class Loader
      Layer = Data.define(:name, :root)

      CORE_NAMESPACE = "nibble::".freeze
      LOCKED = %w[fieldsets].freeze

      def initialize(layers:, disabled: [])
        @layers = layers.map { |name, root| Layer.new(name:, root: Pathname(root)) }
        @disabled = Array(disabled).map(&:to_s)
      end

      def load
        items = {}
        @layers.each do |layer|
          next unless layer.root.directory?

          Dir.glob("**/*.yml", base: layer.root).sort.each do |relative|
            next if relative.start_with?("migrations/")

            item = build_item(layer, relative)
            items[item.key] = item
          end
        end
        apply_disabled(items)
        check_references(items)
        items.values
      end

      private

      def build_item(layer, relative)
        path = layer.root.join(relative)
        parts = relative.delete_suffix(".yml").split("/")
        kind = parts.first
        data = read(path)

        kind, parent, handle = locate(path, kind, parts)
        raise SchemaError.new(file: path, reason: "handles can't contain '::' (reserved for core fieldsets)") if handle.include?("::")
        handle = "#{CORE_NAMESPACE}#{handle}" if kind == "fieldsets" && layer.name == :core
        validate(path, kind, data)

        Item.new(kind:, handle:, parent:, path:, layer: layer.name, data: data.except("schema").freeze)
      end

      def locate(path, kind, parts)
        case kind
        when "search"
          raise SchemaError.new(file: path, reason: "search must be a single file: search.yml") unless parts.size == 1

          [ "search", nil, "search" ]
        when "blueprints"
          return [ "blueprints", "assets", parts[2] ] if parts.size == 3 && parts[1] == "assets" && parts[2] == "asset"

          unless parts.size == 4 && Rules::BLUEPRINT_PARENTS.include?(parts[1])
            raise SchemaError.new(file: path, reason: "blueprints live at blueprints/collections/<collection>/<handle>.yml, blueprints/taxonomies/<taxonomy>/<handle>.yml or blueprints/assets/asset.yml")
          end

          [ "blueprints", "#{parts[1]}/#{parts[2]}", parts[3] ]
        when *Rules::KINDS.keys
          raise SchemaError.new(file: path, reason: "#{kind} files can't be nested in folders") unless parts.size == 2

          [ kind, nil, parts[1] ]
        else
          raise SchemaError.new(file: path, reason: "unknown schema folder '#{kind}' (expected one of: #{Rules::KINDS.keys.join(', ')})")
        end
      end

      def read(path)
        data = YAML.safe_load_file(path, aliases: false) || {}
        raise SchemaError.new(file: path, reason: "must be a YAML mapping") unless data.is_a?(Hash)

        if data.key?("schema") && data["schema"] != Nibble::SCHEMA_FORMAT
          raise SchemaError.new(file: path, key: "schema", reason: "format #{data['schema'].inspect} isn't supported (this version reads #{Nibble::SCHEMA_FORMAT})")
        end

        data
      rescue Psych::Exception => e
        raise SchemaError.new(file: path, reason: "invalid YAML: #{e.message}")
      end

      def validate(path, kind, data)
        rules = Rules::KINDS.fetch(kind)
        body = data.except("schema")
        (rules[:required] - body.keys).each { |key| raise SchemaError.new(file: path, key:, reason: "is required") }
        body.each do |key, value|
          check = rules[:keys][key] or raise SchemaError.new(file: path, key:, reason: "unknown key (allowed: #{rules[:keys].keys.join(', ')})")
          raise SchemaError.new(file: path, key:, reason: "has an invalid value: #{value.inspect}") unless check.(value)
        end
      end

      def locked?(item)
        LOCKED.include?(item.kind) && item.layer == :core
      end

      def apply_disabled(items)
        @disabled.each do |key|
          item = items[key] or raise SchemaError.new(file: "config/nibble.yml", key: "disable", reason: "#{key} doesn't exist in the schema")
          raise SchemaError.new(file: "config/nibble.yml", key: "disable", reason: "#{key} is core-owned and can't be disabled") if locked?(item)

          items.delete(key)
          items.delete_if { |_, other| other.kind == "blueprints" && other.parent == key } if %w[collections taxonomies].include?(item.kind)
        end
      end

      def check_references(items)
        items.each_value do |item|
          case item.kind
          when "collections", "taxonomies"
            Array(item["blueprints"]).each_with_index do |blueprint, index|
              next if items.key?("blueprints/#{item.key}/#{blueprint}")

              raise SchemaError.new(file: item.path, key: "blueprints.#{index}", reason: "no blueprint at blueprints/#{item.key}/#{blueprint}.yml")
            end
            Array(item["taxonomies"]).each_with_index do |taxonomy, index|
              next if items.key?("taxonomies/#{taxonomy}")

              raise SchemaError.new(file: item.path, key: "taxonomies.#{index}", reason: "no taxonomy '#{taxonomy}'")
            end
          when "blueprints"
            next if item.parent == "assets" || items.key?(item.parent)

            raise SchemaError.new(file: item.path, reason: "belongs to #{item.parent}, which isn't defined")
          end
        end
      end
    end
  end
end
