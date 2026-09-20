module NibbleFakes
  class FakeText < Nibble::Fieldtype
    self.config_field_items = {
      "character_limit" => { "type" => "fake_integer" },
      "input_type" => { "type" => "fake_text", "default" => "text" }
    }
  end

  class FakeInteger < Nibble::Fieldtype
    def default_value = 0
    def process(value) = value.presence && value.to_i
  end

  class FakeUpcase < Nibble::Fieldtype
    def pre_process(raw) = raw.to_s.downcase
    def process(value) = value.to_s.upcase
    def preload = { "hint" => "upcased on save" }
  end

  class FakeRows < Nibble::Fieldtype
    self.config_field_items = { "fields" => { "type" => "fake_text" } }

    def child_fields = Nibble::Fields.new(config("fields"), source: "fake rows")

    def extra_rules(root_values: nil, prefix: "", replacements: {})
      Array(field.value).each_with_index.reduce({}) do |rules, (row, index)|
        rules.merge(Nibble::Validator.collect_rules(child_fields, row, root_values:, prefix: "#{prefix}#{index}.", replacements:))
      end
    end
  end
end

module NibbleSchemaHelper
  FAKE_FIELDTYPES = %w[NibbleFakes::FakeText NibbleFakes::FakeInteger NibbleFakes::FakeUpcase NibbleFakes::FakeRows].freeze

  def register_fake_fieldtypes
    FAKE_FIELDTYPES.each { |name| Nibble::Fieldtypes.register(name) }
  end

  def unregister_fake_fieldtypes
    FAKE_FIELDTYPES.each { |name| Nibble::Fieldtypes.unregister(name.constantize.handle) }
  end

  def schema_item(kind, handle, data = {}, parent: nil, layer: :core, path: "/schema/#{kind}/#{handle}.yml", **attributes)
    Nibble::Schema::Item.new(kind:, handle:, parent:, path: Pathname(path), layer:, data: data.merge(attributes).deep_stringify_keys)
  end
end
