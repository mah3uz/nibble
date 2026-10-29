module Nibble
  module Fieldtypes
    class Date < Fieldtype
      LOCAL = /\A(\d{4})-(\d\d)-(\d\d)(?:[T ](\d\d):(\d\d)(?::(\d\d))?)?\z/

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
          "time_seconds_enabled" => { "type" => "toggle", "default" => false, "width" => 50, "if" => { "time_enabled" => true } },
          "time_zone" => { "type" => "text", "width" => 50, "if" => { "time_enabled" => true },
                           "instructions" => "An IANA time zone such as Europe/London, or site for the site's own" }
        } },
        { "display" => "Boundaries & Limits", "fields" => {
          "earliest_date" => { "type" => "date", "width" => 50 },
          "latest_date" => { "type" => "date", "width" => 50 }
        } }
      ]

      def self.zone(name)
        TZInfo::Timezone.get(name.to_s) && ActiveSupport::TimeZone[name.to_s]
      rescue TZInfo::InvalidTimezoneIdentifier
        nil
      end

      # A wall-clock time the clocks skip is nil; one they repeat takes the first, with the larger offset.
      def self.local(text, zone)
        parts = LOCAL.match(text.to_s.strip) or return
        year, month, day, hour, minute, second = parts.captures.map(&:to_i)
        return unless ::Date.valid_date?(year, month, day) && hour < 24 && minute < 60 && second < 60

        wall = ::Time.utc(year, month, day, hour, minute, second)
        period = zone.tzinfo.periods_for_local(wall).max_by(&:utc_total_offset) or return
        (wall - period.utc_total_offset).in_time_zone(zone)
      end

      def self.skipped?(value, name)
        zone = zone(name)
        zone && value.is_a?(String) && LOCAL.match?(value.strip) && local(value, zone).nil? && local(value, ActiveSupport::TimeZone["UTC"]).present?
      end

      def time_zone
        name = config("time_zone")
        return unless time_enabled? && name.present?

        name = ::Time.zone.tzinfo.name if name == "site"
        name if self.class.zone(name)
      end

      def pre_process(value)
        return nil if value.blank?
        return "now" if value == "now"

        time = parse(value) or return nil
        return time.iso8601 if zone

        time_enabled? ? time.utc.iso8601(3) : time.to_date.iso8601
      end

      def pre_process_validatable(value)
        return value unless zone && value.is_a?(String) && value != "now"

        parse(value)&.iso8601 || value
      end

      def process(value)
        return nil if value.blank?

        time = parse(value) or return value
        return time.to_date.iso8601 unless time_enabled?

        time = time.change(sec: 0) unless config("time_seconds_enabled")
        time.utc.iso8601
      end

      def preload = { "timezone" => time_zone || ::Time.zone.tzinfo.name, "zoned" => time_zone.present? }

      def pre_process_index(value) = value.blank? ? nil : { "date" => pre_process(value), "time_enabled" => time_enabled? }

      def augment(value)
        return nil if value.blank?

        time = parse(value) or return nil
        return time.iso8601 if zone

        time_enabled? ? time.utc.iso8601 : time.to_date.iso8601
      end

      def rules
        [
          "date",
          *("local_time:#{time_zone}" if zone),
          *("after_or_equal:#{bound(config('earliest_date'))}" if config("earliest_date").present?),
          *("before_or_equal:#{bound(config('latest_date'))}" if config("latest_date").present?)
        ]
      end

      def config_problems
        name = config("time_zone")
        return [] if name.nil? || name == "site" || self.class.zone(name)

        [ "time_zone #{name.inspect} isn't an IANA time zone such as Europe/London, or site" ]
      end

      def ts_type = "string | null"

      private

      def time_enabled? = config("time_enabled") == true

      def zone = (name = time_zone) && ActiveSupport::TimeZone[name]

      def bound(date) = zone && (local = self.class.local(date.to_s, zone)) ? local.iso8601 : date

      def parse(value)
        return zoned(value) if zone

        case value
        when ::Time, ActiveSupport::TimeWithZone then value
        when ::Date then value.in_time_zone
        when "now" then ::Time.current
        else time_enabled? ? ::Time.zone.parse(value.to_s) : ::Date.iso8601(value.to_s[0, 10]).in_time_zone
        end
      rescue ArgumentError, ::Date::Error
        nil
      end

      def zoned(value)
        case value
        when ::Time, ActiveSupport::TimeWithZone then value.in_time_zone(zone)
        when ::Date then self.class.local(value.iso8601, zone)
        when "now" then ::Time.current.in_time_zone(zone)
        else LOCAL.match?(value.to_s.strip) ? self.class.local(value, zone) : ::Time.zone.parse(value.to_s)&.in_time_zone(zone)
        end
      rescue ArgumentError
        nil
      end
    end
  end
end
