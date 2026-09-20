module Nibble
  module Fieldtypes
    class Date < Fieldtype
      self.categories = %w[special]
      self.contract_samples = [ "2026-09-17", nil ]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Appearance", "fields" => {
          "inline" => { "type" => "toggle", "default" => false, "width" => 50 },
          "full_width" => { "type" => "toggle", "default" => false, "width" => 50 }
        } },
        { "display" => "Timepicker", "fields" => {
          "time_enabled" => { "type" => "toggle", "default" => false, "width" => 50 },
          "time_seconds_enabled" => { "type" => "toggle", "default" => false, "width" => 50, "if" => { "time_enabled" => true } }
        } },
        { "display" => "Boundaries & Limits", "fields" => {
          "earliest_date" => { "type" => "date", "width" => 50 },
          "latest_date" => { "type" => "date", "width" => 50 }
        } }
      ]

      def pre_process(value)
        return nil if value.blank?
        return "now" if value == "now"

        time = parse(value) or return nil
        time_enabled? ? time.utc.iso8601(3) : time.to_date.iso8601
      end

      def process(value)
        return nil if value.blank?

        time = parse(value) or return value
        return time.to_date.iso8601 unless time_enabled?

        time = time.change(sec: 0) unless config("time_seconds_enabled")
        time.utc.iso8601
      end

      def preload = { "timezone" => Time.zone.tzinfo.name }

      def pre_process_index(value) = value.blank? ? nil : { "date" => pre_process(value), "time_enabled" => time_enabled? }

      def augment(value)
        return nil if value.blank?

        time = parse(value) or return nil
        time_enabled? ? time.utc.iso8601 : time.to_date.iso8601
      end

      def rules
        [
          "date",
          *("after_or_equal:#{config('earliest_date')}" if config("earliest_date").present?),
          *("before_or_equal:#{config('latest_date')}" if config("latest_date").present?)
        ]
      end

      def ts_type = "string | null"

      private

      def time_enabled? = config("time_enabled") == true

      def parse(value)
        case value
        when ::Time, ActiveSupport::TimeWithZone then value
        when ::Date then value.in_time_zone
        when "now" then Time.current
        else time_enabled? ? Time.zone.parse(value.to_s) : ::Date.iso8601(value.to_s[0, 10]).in_time_zone
        end
      rescue ArgumentError, ::Date::Error
        nil
      end
    end
  end
end
