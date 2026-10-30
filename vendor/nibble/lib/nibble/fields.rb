module Nibble
  class Fields
    include Enumerable

    SET_ADJUSTMENTS = %w[add_sets remove_sets].freeze
    FIELDSET_REFERENCE =/\A(?<fieldset>.+)\.(?<field>[a-z0-9_]+)\z/

    attr_reader :source, :parent_field, :parent_index

    def initialize(items, schema: nil, source: nil, key: nil, parent_field: nil, parent_index: nil, fields: nil, stack: [], check_config: true)
      @schema = schema
      @check_config = check_config
      @source = source
      @key = key
      @parent_field = parent_field
      @parent_index = parent_index
      @fields = fields || resolve(Array(items), stack)
    end

    def each(&) = @fields.each_value(&)
    def all = @fields
    def handles = @fields.keys
    def get(handle) = @fields[handle.to_s]
    def [](handle) = get(handle)
    def has?(handle) = @fields.key?(handle.to_s)
    def empty? = @fields.empty?

    def only(*handles) = copy(@fields.slice(*handles.flatten.map(&:to_s)))
    def except(*handles) = copy(@fields.except(*handles.flatten.map(&:to_s)))
    def localizable = copy(@fields.select { |_, field| field.localizable? })

    def add_values(values)
      values = values.to_h.stringify_keys
      copy(@fields.transform_values { |field| field.with_value(values[field.handle]) })
    end

    def values = @fields.transform_values(&:value)

    # What something new starts with: a record when it's created, a row when it's added.
    def defaults = @fields.transform_values(&:default_value).compact
    def with_defaults(values = {}) = add_values(defaults.merge(values.to_h.stringify_keys))

    def pre_process = map_fields(&:pre_process)
    def process = map_fields(&:process)
    def pre_process_validatable = map_fields(&:pre_process_validatable)
    def augment = map_fields(&:augment)
    def shallow_augment = map_fields(&:shallow_augment)
    def meta = @fields.transform_values(&:meta)

    def to_publish_a = @fields.values.map(&:to_publish_h)

    private

    def copy(fields)
      self.class.new(nil, schema: @schema, source: @source, key: @key, parent_field: @parent_field, parent_index: @parent_index, fields:, check_config: @check_config)
    end

    def map_fields(&) = copy(@fields.transform_values(&))

    def resolve(items, stack)
      items.each_with_index.with_object({}) do |(item, index), fields|
        item = item.to_h.deep_stringify_keys
        key = [ @key, index ].compact.join(".")
        created = if item.key?("import")
          imported(item, key, stack)
        else
          [ single(item, key, stack) ]
        end
        created.each do |field|
          fail!(key, "duplicate field handle '#{field.handle}'") if fields.key?(field.handle)
          fields[field.handle] = field
        end
      end
    end

    def single(item, key, stack)
      handle = item["handle"]
      fail!(key, "field is missing a handle") unless handle.is_a?(String) && handle.match?(/\A[a-z][a-z0-9_]*\z/)

      case (definition = item["field"])
      when Hash
        build(handle, definition, key)
      when String
        referenced(handle, definition, item["config"], key, stack)
      else
        fail!("#{key}.field", "must be a field config or a 'fieldset.field' reference")
      end
    end

    def referenced(handle, reference, overrides, key, stack)
      match = FIELDSET_REFERENCE.match(reference) or fail!("#{key}.field", "invalid reference '#{reference}' (expected fieldset.field)")
      fieldset = fieldset_fields(match[:fieldset], key, stack)
      field = fieldset.get(match[:field]) or fail!("#{key}.field", "fieldset '#{match[:fieldset]}' has no field '#{match[:field]}'")
      overrides = overrides.to_h
      config = field.config.merge(overrides.except(*SET_ADJUSTMENTS))
      config = adjust_sets(config, overrides, key) if overrides.keys.intersect?(SET_ADJUSTMENTS)
      build(handle, config, key)
    end

    def adjust_sets(config, overrides, key)
      base = config["sets"]
      fail!("#{key}.config", "add_sets and remove_sets need a field that has sets") unless base.is_a?(Hash)

      groups = grouped_sets(base)
      existing = groups.values.flat_map { |group| group["sets"].keys }

      Array(overrides["remove_sets"]).map(&:to_s).each do |set|
        fail!("#{key}.config.remove_sets", "set '#{set}' isn't in the field, which has #{existing.join(', ')}") unless existing.include?(set)
        groups.each_value { |group| group["sets"].delete(set) }
      end
      groups.reject! { |_, group| group["sets"].empty? }

      overrides["add_sets"].to_h.each do |group_handle, added|
        added = added.to_h
        if groups.key?(group_handle)
          groups[group_handle]["sets"].merge!(added_sets(added, groups, "#{key}.config.add_sets.#{group_handle}"))
        else
          fail!("#{key}.config.add_sets.#{group_handle}", "a new group needs a 'sets' map of its sets") unless added["sets"].is_a?(Hash)
          groups[group_handle] = added.merge("sets" => added_sets(added["sets"], groups, "#{key}.config.add_sets.#{group_handle}.sets"))
        end
      end

      config.merge("sets" => groups)
    end

    def added_sets(added, groups, key)
      taken = groups.values.flat_map { |group| group["sets"].keys }
      added.each_key do |set|
        fail!("#{key}.#{set}", "set '#{set}' already exists; replace it with 'config: sets', or pick another handle") if taken.include?(set)
      end
      added
    end

    def grouped_sets(sets)
      first = sets.values.first
      return sets.transform_values { |group| group.merge("sets" => group["sets"].to_h.dup) } if first.is_a?(Hash) && first.key?("sets")

      { "main" => { "sets" => sets.dup } }
    end

    def imported(item, key, stack)
      fieldset = fieldset_fields(item["import"].to_s, key, stack)
      overrides = item["config"].to_h
      prefix = item["prefix"]
      fieldset.all.values.map do |field|
        handle = prefix ? "#{prefix}#{field.handle}" : field.handle
        build(handle, field.config.merge(overrides[field.handle].to_h), key, prefix: prefix ? "#{prefix}#{field.prefix}" : field.prefix)
      end
    end

    def fieldset_fields(handle, key, stack)
      fail!(key, "fieldset import loop: #{[ *stack, handle ].join(' → ')}") if stack.include?(handle)
      item = @schema&.fieldset(handle) or fail!(key, "no fieldset '#{handle}'")
      Fields.new(item["fields"], schema: @schema, source: item.path, key: "fields", stack: [ *stack, handle ])
    end

    def build(handle, config, key, prefix: nil)
      type = config.fetch("type", "text")
      fail!("#{key}.field.type", "unknown fieldtype '#{type}'") if @check_config && !Fieldtypes.exists?(type)

      field = Field.new(handle, config, prefix:, parent_field: @parent_field, parent_index: @parent_index, schema: @schema)
      field.config_errors.each { |option, reason| fail!("#{key}.field.#{option}", reason) } if @check_config
      field
    end

    def fail!(key, reason)
      raise SchemaError.new(file: @source || "(inline fields)", key:, reason:)
    end
  end
end
