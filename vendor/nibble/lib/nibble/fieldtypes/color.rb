module Nibble
  module Fieldtypes
    class Color < Fieldtype
      HEX = /\A#[0-9a-f]{6}\z/

      self.categories = %w[controls]
      self.contract_samples = [ "#1a2b3c", nil ]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Selection & Options", "fields" => {
          "swatches" => { "type" => "list", "default" => [] },
          "allow_any" => { "type" => "toggle", "default" => true }
        } }
      ]

      def self.normalize(value) = value.is_a?(String) ? value.strip.downcase : value

      def self.valid?(value) = value.is_a?(String) && HEX.match?(value)

      def swatches = Array(config("swatches")).map { |swatch| self.class.normalize(swatch) }

      def allow_any? = config("allow_any") != false

      def pre_process_validatable(value) = self.class.normalize(value)

      def process(value) = value.blank? ? nil : self.class.normalize(value)

      def rules = [ "color", *("in:#{swatches.join(',')}" unless allow_any? || swatches.empty?) ]

      def config_problems
        problems = swatches.reject { |swatch| self.class.valid?(swatch) }.map { |swatch| "swatch #{swatch.inspect} isn't a colour written as #rrggbb" }
        problems << "has allow_any: false but no swatches to choose from" if !allow_any? && swatches.empty?
        default = self.class.normalize(field&.get("default"))
        return problems if default.nil?

        problems << "default #{default.inspect} isn't a colour written as #rrggbb" unless self.class.valid?(default)
        problems << "default #{default} isn't one of its swatches" if self.class.valid?(default) && !allow_any? && !swatches.include?(default)
        problems
      end

      def json_schema
        return { "type" => "string", "enum" => swatches, "description" => "One of the swatches" } unless allow_any?

        { "type" => "string", "pattern" => "^#[0-9a-fA-F]{6}$", "description" => "A colour as #rrggbb, stored in lowercase" }
      end

      def ts_type = "string | null"
    end
  end
end
