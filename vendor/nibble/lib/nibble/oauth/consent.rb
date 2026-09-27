module Nibble
  module Oauth
    # What one person may hand an app, given their roles and the site's agent access settings.
    class Consent
      PRESETS = {
        "read" => [ "Read", "See the content you can see. Change nothing." ],
        "draft" => [ "Draft", "Create entries and edit drafts, and send them for review. Nothing goes live." ],
        "everything" => [ "Everything I can do", "Anything your role allows within the site's agent settings, publishing included." ],
        "custom" => [ "Custom", "Choose area by area." ]
      }.freeze

      def initialize(user, device: false, schema: Nibble.schema)
        @user = user
        @device = device
        @schema = schema
      end

      def presets
        PRESETS.map do |value, (label, description)|
          { value:, label:, description:, available: available?(value) }
        end
      end

      def areas
        AgentAccess.areas(schema: @schema).map do |area|
          { key: area.key, title: area.title, group: area.group,
            columns: area.columns.map { |column| { value: column, label: AgentAccess::COLUMNS[column], available: column_available?(area.key, column) } } }
        end
      end

      def abilities(preset, selection = {})
        raise Error.new("invalid_request", "choose what the app may do") unless PRESETS.key?(preset.to_s) && available?(preset.to_s)
        return AgentAccess.preset(preset) unless preset.to_s == "custom"

        chosen = selection.to_h.flat_map { |area, columns| Array(columns).map { |column| [ area.to_s, column.to_s ] } }
        raise Error.new("invalid_request", "choose at least one thing the app may do") if chosen.empty?

        chosen.flat_map do |area, column|
          raise Error.new("invalid_request", "#{area} #{column} isn't available") unless column_available?(area, column)

          AgentAccess.abilities_for(area, column)
        end.uniq
      end

      private

      def available?(preset)
        case preset
        when "read" then AgentAccess.areas(schema: @schema).any? { |area| column_available?(area.key, "read") }
        when "draft" then @schema.collections.any? { |item| column_available?("entries.#{item.handle}", "write") }
        when "everything" then !@device
        else true
        end
      end

      def column_available?(area, column)
        known = AgentAccess.areas(schema: @schema).find { |item| item.key == area }
        known&.columns&.include?(column) && AgentAccess.value(area, column) && AgentAccess.person_can?(@user, area, column, schema: @schema)
      end
    end
  end
end
