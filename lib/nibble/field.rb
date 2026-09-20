module Nibble
  class Field
    VISIBILITIES = %w[visible read_only hidden computed].freeze
    WIDTHS = [ 25, 33, 50, 66, 75, 100 ].freeze
    CONDITION_KEYS = %w[if if_any unless unless_any show_when show_when_any hide_when hide_when_any].freeze
    BOOLEAN = ->(value) { value == true || value == false }

    COMMON_OPTIONS = {
      "type" => ->(value) { value.is_a?(String) },
      "display" => ->(value) { value.is_a?(String) },
      "instructions" => ->(value) { value.is_a?(String) },
      "instructions_position" => ->(value) { %w[above below].include?(value) },
      "width" => ->(value) { WIDTHS.include?(value) },
      "required" => BOOLEAN,
      "validate" => ->(value) { value.is_a?(String) || (value.is_a?(Array) && value.all? { |rule| rule.is_a?(String) }) },
      "default" => ->(_value) { true },
      "visibility" => ->(value) { VISIBILITIES.include?(value) },
      "read_only" => BOOLEAN,
      "always_save" => BOOLEAN,
      "localizable" => BOOLEAN,
      "listable" => ->(value) { [ true, false, "hidden" ].include?(value) },
      "sortable" => BOOLEAN,
      "filterable" => BOOLEAN,
      "duplicate" => BOOLEAN,
      "replicator_preview" => BOOLEAN,
      "hide_display" => BOOLEAN,
      "actions" => BOOLEAN,
      "api" => BOOLEAN,
      **CONDITION_KEYS.to_h { |key| [ key, ->(value) { value.is_a?(Hash) || value.is_a?(String) } ] }
    }.freeze

    COMPUTED_DEFAULT_PREFIX = "computed:".freeze

    attr_reader :handle, :config, :prefix, :parent_field, :parent_index, :value

    def initialize(handle, config, prefix: nil, parent_field: nil, parent_index: nil, value: nil, schema: nil)
      @schema = schema
      @handle = handle.to_s
      @config = config.to_h.deep_stringify_keys.freeze
      @prefix = prefix
      @parent_field = parent_field
      @parent_index = parent_index
      @value = value
    end

    def with(handle: @handle, config: @config, prefix: @prefix, parent_field: @parent_field, parent_index: @parent_index, value: @value)
      self.class.new(handle, config, prefix:, parent_field:, parent_index:, value:, schema: @schema)
    end

    def schema = @schema || Nibble.schema

    def with_value(value) = with(value:)

    def type = config.fetch("type", "text")
    def fieldtype_class = Fieldtypes.find(type)
    def fieldtype = fieldtype_class.new(self)

    def get(key, fallback = nil)
      value = config[key.to_s]
      value.nil? ? fallback : value
    end

    def display = get("display", handle.humanize)
    def instructions = get("instructions")

    def visibility
      return get("visibility") if get("visibility")

      get("read_only") ? "read_only" : "visible"
    end

    def required? = get("required", false) == true || validation_rules.include?("required")
    def always_save? = get("always_save", false)
    def localizable? = get("localizable", false)
    def api? = get("api", true)
    def duplicate? = get("duplicate", true)
    def computed? = visibility == "computed"

    def listable? = get("listable", "hidden") != false
    def visible_on_listing? = get("listable", "hidden") == true

    def sortable?
      return false if computed?

      get("sortable", true)
    end

    def filterable? = get("filterable", listable?)

    def validation_rules
      rules = get("validate", [])
      rules.is_a?(String) ? rules.split("|") : rules
    end

    def conditions = config.slice(*CONDITION_KEYS)

    def computed_default? = get("default").is_a?(String) && get("default").start_with?(COMPUTED_DEFAULT_PREFIX)

    def default_value
      if computed_default?
        Defaults.resolve(get("default").delete_prefix(COMPUTED_DEFAULT_PREFIX))
      elsif config.key?("default")
        config["default"]
      else
        fieldtype.default_value
      end
    end

    def path_keys = [ *parent_field&.path_keys, *parent_index, handle ].map(&:to_s)
    def path = path_keys.join(".")

    def pre_process = with_value(fieldtype.pre_process(value.nil? ? default_value : value))
    def process = with_value(fieldtype.process(value))
    def pre_process_index = with_value(fieldtype.pre_process_index(value))
    def pre_process_validatable = with_value(fieldtype.pre_process_validatable(value))
    def augment = with_value(fieldtype.augment(value))
    def shallow_augment = with_value(fieldtype.shallow_augment(value))
    def meta = fieldtype.preload

    def config_errors
      errors = []
      allowed = fieldtype_class.config_fields.handles
      config.each do |key, value|
        if (check = COMMON_OPTIONS[key])
          errors << [ key, "has an invalid value: #{value.inspect}" ] unless check.(value)
        elsif !allowed.include?(key)
          errors << [ key, "isn't an option of the #{type} fieldtype" ]
        end
      end
      errors
    end

    def to_publish_h
      type_config = fieldtype.publish_config(fieldtype_class.config_defaults.merge(config.except(*COMMON_OPTIONS.keys)))
      {
        "handle" => handle,
        "prefix" => prefix,
        "type" => type,
        "component" => fieldtype.component,
        "display" => display,
        "instructions" => instructions,
        "instructions_position" => get("instructions_position", "above"),
        "width" => get("width", 100),
        "required" => required?,
        "visibility" => visibility,
        "read_only" => visibility == "read_only",
        "always_save" => always_save?,
        "localizable" => localizable?,
        "hide_display" => get("hide_display", false),
        "replicator_preview" => get("replicator_preview", true),
        "actions" => get("actions", true),
        **conditions,
        "config" => type_config
      }
    end
  end
end
