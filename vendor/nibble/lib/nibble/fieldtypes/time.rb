module Nibble
  module Fieldtypes
    class Time < Fieldtype
      FORMAT = /\A([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?\z/
      PATTERN = "^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$".freeze

      self.categories = %w[special]
      self.contract_samples = [ "09:30", "23:05", nil ]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Appearance", "fields" => { "placeholder" => { "type" => "text" } } },
        { "display" => "Timepicker", "fields" => { "seconds" => { "type" => "toggle", "default" => false } } },
        { "display" => "Boundaries and limits", "fields" => {
          "earliest" => { "type" => "time", "width" => 50 },
          "latest" => { "type" => "time", "width" => 50 }
        } }
      ]

      def self.valid?(value) = value.is_a?(String) && FORMAT.match?(value)

      def self.compare(left, right) = padded(left) <=> padded(right)

      def self.padded(value) = value.length == 5 ? "#{value}:00" : value

      def process(value)
        return nil if value.blank?

        text = value.to_s.strip
        return text unless self.class.valid?(text)

        config("seconds") == true ? self.class.padded(text) : text[0, 5]
      end

      def rules
        [ "time", *("earliest_time:#{config('earliest')}" if self.class.valid?(config("earliest"))),
          *("latest_time:#{config('latest')}" if self.class.valid?(config("latest"))) ]
      end

      def config_problems
        problems = %w[earliest latest default].filter_map do |key|
          value = field&.get(key)
          "#{key} must be a time written in quotes, such as '09:30'" unless value.nil? || self.class.valid?(value)
        end
        earliest, latest = config("earliest"), config("latest")
        if self.class.valid?(earliest) && self.class.valid?(latest) && self.class.compare(earliest, latest).positive?
          problems << "earliest #{earliest} is after latest #{latest}"
        end
        problems
      end

      def json_schema
        { "type" => "string", "pattern" => PATTERN, "description" => "A time of day on the 24-hour clock, as HH:MM#{' or HH:MM:SS' if config('seconds') == true}" }
      end

      def ts_type = "string | null"
    end
  end
end
