module Nibble
  module Fieldtypes
    class Markdown < Fieldtype
      ASSET_URL = %r{nibble://asset/([^\s)"']+)}

      self.categories = %w[text structured]
      self.contract_samples = [ "## Heading\n\nSome **text**.", nil ]
      self.keywords = %w[markdown text prose docs]
      self.selectable_in_forms = true
      self.config_field_items = [
        { "display" => "Editor Settings", "fields" => {
          "placeholder" => { "type" => "text", "width" => 50 },
          "character_limit" => { "type" => "integer", "width" => 50 },
          "rows" => { "type" => "integer", "default" => 12, "width" => 50 },
          "preview" => { "type" => "toggle", "default" => true, "width" => 50 }
        } },
        { "display" => "Data & Format", "fields" => {
          "sanitize" => { "type" => "toggle", "default" => false },
          "image_preset" => { "type" => "text", "default" => "content", "width" => 50 }
        } }
      ]

      def rules = config("character_limit").to_i.positive? ? [ "max:#{config('character_limit')}" ] : []

      def augment(value)
        text = value.to_s
        return nil if text.blank?

        Nibble::Markdown.render(resolve_assets(text), sanitize: config("sanitize") == true)
      end

      def import(value, ctx = nil) = transfer(value, ctx)
      def export(value, ctx = nil) = transfer(value, ctx)

      def relations(value) = super + asset_ids(value).map { |id| [ "asset", id ] }
      def dependencies(value) = super + asset_ids(value).map { |id| "asset:#{id}" }

      def pre_process_index(value) = value.to_s.gsub(/[#*`_>\[\]]/, "").squish.truncate(100).presence
      def search_text(value) = value.is_a?(String) ? value : nil
      def ts_type = "string | null"

      private

      # Stored as a reference rather than a URL, so an asset can move or be replaced without every document
      # that points at it going stale.
      def resolve_assets(text)
        ids = asset_ids(text)
        return text if ids.empty?

        found = Resolvers.find("asset").find(ids).index_by { |summary| summary["id"] }
        text.gsub(ASSET_URL) { found.dig(Regexp.last_match(1), "url") || Regexp.last_match(0) }
      end

      def transfer(value, ctx)
        return value unless ctx && value.present?

        value.to_s.gsub(ASSET_URL) { "nibble://asset/#{ctx.resolve('asset', Regexp.last_match(1))}" }
      end

      def asset_ids(value) = value.to_s.scan(ASSET_URL).flatten.uniq
    end
  end
end
