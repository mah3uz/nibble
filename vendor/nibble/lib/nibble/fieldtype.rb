module Nibble
  class Fieldtype
    CATEGORIES = %w[text number controls media relationship structured special].freeze

    class_attribute :title, instance_writer: false
    class_attribute :icon, instance_writer: false
    class_attribute :categories, instance_writer: false, default: []
    class_attribute :keywords, instance_writer: false, default: []
    class_attribute :selectable, instance_writer: false, default: true
    class_attribute :selectable_in_forms, instance_writer: false, default: false
    class_attribute :localizable, instance_writer: false, default: true
    class_attribute :validatable, instance_writer: false, default: true
    class_attribute :defaultable, instance_writer: false, default: true
    class_attribute :relationship, instance_writer: false, default: false
    class_attribute :config_field_items, instance_writer: false, default: {}
    class_attribute :extra_config_field_items, instance_writer: false, default: {}
    class_attribute :component_name, instance_writer: false
    class_attribute :index_component_name, instance_writer: false
    class_attribute :contract_samples, instance_writer: false, default: [ nil ]

    class << self
      def handle = name.demodulize.underscore

      def display_title = title || handle.humanize

      def append_config_fields(fields)
        self.extra_config_field_items = extra_config_field_items.merge(fields.deep_stringify_keys)
        @config_fields = nil
      end

      def config_fields
        @config_fields ||= Fields.new(config_field_entries, source: "fieldtype #{handle} config", check_config: false)
      end

      def config_defaults = config_fields.all.transform_values { |field| field.get("default") }

      def config_sections
        items = config_field_items.is_a?(Array) ? config_field_items : [ { "fields" => config_field_items } ]
        sections = items.map { |section| section.deep_stringify_keys }
        sections << { "fields" => extra_config_field_items } if extra_config_field_items.any?
        sections
      end

      def to_h
        {
          handle:, title: display_title, icon: icon || "fieldtype-#{handle}", categories:, keywords:,
          selectable:, selectable_in_forms:, localizable:, validatable:, defaultable:, relationship:,
          config: config_fields.to_publish_a
        }
      end

      private

      def config_field_entries
        config_sections.flat_map do |section|
          section.fetch("fields", {}).map { |handle, config| { "handle" => handle, "field" => config } }
        end
      end
    end

    attr_reader :field

    def initialize(field = nil)
      @field = field
    end

    def handle = self.class.handle
    def component = component_name || handle
    def index_component = index_component_name || handle

    def config(key = nil, fallback = nil)
      values = self.class.config_defaults.merge(field&.config.to_h.except("type"))
      return values if key.nil?

      value = values[key.to_s]
      value.nil? ? fallback : value
    end

    def migrate_config(config) = config

    def default_value = nil
    def pre_process(raw) = raw
    def preload = nil
    def pre_process_validatable(value) = value
    def rules = []
    def extra_rules(root_values: nil, prefix: "", replacements: {}) = {}
    def process(value) = value
    def pre_process_index(raw) = raw
    def augment(raw) = raw
    def shallow_augment(raw) = augment(raw)

    def nested_fields = []
    def publish_config(config) = config

    def diff(from, to) = from == to ? nil : { "from" => from, "to" => to }

    def relations(_raw) = []
    def dependencies(_raw) = []
    def search_text(_raw) = nil
    def export(raw, _ctx = nil) = raw
    def import(value, _ctx = nil) = value
    # Only the fieldtypes that mint row ids override this; for everything else the incoming value stands.
    def carry_row_ids(_stored, incoming) = incoming
    def queryable_value(_raw) = nil
    def ts_type = "unknown"
  end
end
