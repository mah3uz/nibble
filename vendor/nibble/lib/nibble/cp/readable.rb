module Nibble
  module Cp
    module Readable
      ISO_TIME = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/
      ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/
      TEXT_BLOCKS = %w[paragraph heading listItem blockquote codeBlock tableRow].freeze

      class << self
        def value(value, field = nil)
          return count(value, "file") if field&.type == "assets" && value.is_a?(Array)

          case value
          when nil then ""
          when true then "On"
          when false then "Off"
          when String then string(value)
          when Array then array(value, field)
          when Hash then hash(value)
          else value.to_s
          end
        end

        private

        def string(value)
          return Time.zone.parse(value).strftime("%-d %b %Y, %-l:%M %p") if value.match?(ISO_TIME)
          return Date.parse(value).strftime("%-d %b %Y") if value.match?(ISO_DATE)

          value
        rescue ArgumentError
          value
        end

        def array(rows, field)
          return "" if rows.empty?
          return rows.map { |row| value(row, field) }.join(", ") unless rows.all? { |row| row.is_a?(Hash) && row["type"] }

          "#{count(rows, 'block')}: #{rows.map { |row| row['type'].to_s.humanize }.join(', ')}"
        end

        def hash(value)
          return text_of(value).strip if value["type"] == "doc"

          value.filter_map { |key, inner| "#{key.to_s.humanize}: #{self.value(inner)}" if inner.present? || inner == false }.join("\n")
        end

        def text_of(node)
          return node["text"].to_s if node["type"] == "text"

          inner = Array(node["content"]).map { |child| text_of(child) }.join
          TEXT_BLOCKS.include?(node["type"]) ? "#{inner}\n" : inner
        end

        def count(list, noun) = "#{list.size} #{noun.pluralize(list.size)}"
      end
    end
  end
end
