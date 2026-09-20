module UserPreferences
  Definition = Data.define(:key, :type, :default, :options)

  class InvalidValue < StandardError; end

  DEFINITIONS = [
    Definition.new(key: "theme", type: :enum, default: "system", options: %w[system light dark]),
    Definition.new(key: "sidebar_collapsed", type: :boolean, default: false, options: nil),
    Definition.new(key: "layout_expanded", type: :boolean, default: false, options: nil),
    Definition.new(key: "start_page", type: :enum, default: "dashboard", options: nil),
    Definition.new(key: "after_save", type: :enum, default: "continue", options: %w[continue listing create_another]),
    Definition.new(key: "assets.view", type: :enum, default: "grid", options: %w[grid table]),
    Definition.new(key: "dashboard.widgets", type: :widget_list, default: Nibble::Cp::Widgets::DEFAULT, options: nil),
    Definition.new(key: "notifications.email", type: :boolean, default: true, options: nil)
  ].index_by(&:key).freeze

  LISTING_COLUMNS_KEY = /\Alistings\.[a-z_]+\.columns\z/
  LISTING_PER_PAGE_KEY = /\Alistings\.[a-z_]+\.per_page\z/
  LISTING_VIEW_KEY = /\Alistings\.[a-z_]+\.view\z/
  LISTING_PRESETS_KEY = /\Alistings\.[a-z_]+\.presets\z/
  LISTING_PER_PAGE_OPTIONS = [ 25, 50, 100 ].freeze
  LISTING_VIEW_OPTIONS = %w[list tree].freeze
  LISTING_PRESETS_MAX = 10
  WIDGET_WIDTHS = [ 33, 50, 66, 100 ].freeze
  WIDGET_HEIGHT_FORMAT = /\A\d+(\.\d+)?(px|rem)\z/

  module_function

  def all(user)
    DEFINITIONS.each_value.with_object({}) { |definition, hash| deep_set(hash, definition.key, get(user, definition.key)) }
  end

  def get(user, key)
    definition = definition_for(key) or raise ArgumentError, "unknown preference #{key}"
    stored = deep_get(user.preferences, key)
    stored.nil? ? definition.default : stored
  end

  # `value: nil` resets the key to its default (removes the override) instead of storing `nil`.
  def set!(user, key, value)
    definition = definition_for(key) or raise InvalidValue, "#{key} is not a known preference"
    value = deep_unwrap(value)
    error = type_error(definition, value) unless value.nil?
    raise InvalidValue, "#{key} #{error}" if error

    preferences = user.preferences.deep_dup
    value.nil? ? deep_delete(preferences, key) : deep_set(preferences, key, value)
    user.update!(preferences:)
  end

  def start_pages = [ "dashboard", *Nibble.schema.collections.map(&:handle) ]

  def definition_for(key)
    return DEFINITIONS[key].with(options: start_pages) if key == "start_page"
    return DEFINITIONS[key] if DEFINITIONS.key?(key)
    return Definition.new(key:, type: :string_array, default: [], options: nil) if LISTING_COLUMNS_KEY.match?(key)
    return Definition.new(key:, type: :enum, default: 25, options: LISTING_PER_PAGE_OPTIONS) if LISTING_PER_PAGE_KEY.match?(key)
    return Definition.new(key:, type: :enum, default: "list", options: LISTING_VIEW_OPTIONS) if LISTING_VIEW_KEY.match?(key)
    return Definition.new(key:, type: :preset_list, default: [], options: nil) if LISTING_PRESETS_KEY.match?(key)

    nil
  end
  private_class_method :definition_for

  def type_error(definition, value)
    case definition.type
    when :boolean then "must be true or false" unless [ true, false ].include?(value)
    when :enum then "must be one of #{definition.options.join(', ')}" unless definition.options.include?(value)
    when :string_array then "must be a list of column handles" unless value.is_a?(Array) && value.all?(String)
    when :preset_list
      "must be a list of at most #{LISTING_PRESETS_MAX} saved views" unless value.is_a?(Array) &&
        value.size <= LISTING_PRESETS_MAX && value.all? { |v| v.is_a?(Hash) && %w[handle label query].all? { |k| v.key?(k) } }
    when :widget_list
      "must be a list of widgets with a type, a width of #{WIDGET_WIDTHS.join(', ')}, and an optional height in px or rem (e.g. \"20rem\")" unless value.is_a?(Array) &&
        value.all? { |v| v.is_a?(Hash) && v["type"].is_a?(String) && WIDGET_WIDTHS.include?(v["width"]) && valid_widget_height?(v["height"]) }
    end
  end
  private_class_method :type_error

  def valid_widget_height?(value)
    value.nil? || (value.is_a?(String) && WIDGET_HEIGHT_FORMAT.match?(value))
  end
  private_class_method :valid_widget_height?

  # Parameters nested in a request body aren't the plain Hash and Array the json column expects.
  def deep_unwrap(value)
    case value
    when ActionController::Parameters then deep_unwrap(value.to_unsafe_h)
    when Hash then value.transform_values { |v| deep_unwrap(v) }
    when Array then value.map { |v| deep_unwrap(v) }
    else value
    end
  end
  private_class_method :deep_unwrap

  def deep_get(hash, key)
    key.split(".").reduce(hash) { |value, segment| value.is_a?(Hash) ? value[segment] : nil }
  end
  private_class_method :deep_get

  def deep_set(hash, key, value)
    segments = key.split(".")
    segments[0..-2].reduce(hash) { |h, segment| h[segment] ||= {} }[segments.last] = value
  end
  private_class_method :deep_set

  def deep_delete(hash, key)
    segments = key.split(".")
    parent = segments[0..-2].reduce(hash) { |h, segment| h.is_a?(Hash) ? h[segment] : nil }
    parent.is_a?(Hash) && parent.delete(segments.last)
  end
  private_class_method :deep_delete
end
