module Nibble
  module Fieldtypes
    class Markdown < Fieldtype
      ASSET_URL = %r{nibble://asset/([^\s)"']+)}
      PAGE_URL = %r{nibble://page/([^\s)"'#]+)(#[^\s)"']*)?}

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

        @srcsets = {}
        responsive(Nibble::Markdown.render(resolve_pages(resolve_assets(text)), sanitize: config("sanitize") == true))
      end

      def import(value, ctx = nil) = transfer(value, ctx)
      def export(value, ctx = nil) = transfer(value, ctx)

      def relations(value) = super + asset_ids(value).map { |id| [ "asset", id ] }
      def dependencies(value) = super + asset_ids(value).map { |id| "asset:#{id}" }

      def pre_process_index(value) = value.to_s.gsub(/[#*`_>\[\]]/, "").squish.truncate(100).presence
      def search_text(value) = value.is_a?(String) ? Nibble::Markdown.text(value) : nil
      def ts_type = "string | null"

      private

      # Stored as a reference rather than a URL, so an asset can move or be replaced without every document
      # that points at it going stale.
      # The browser's own assumption, so this cannot fetch more than no srcset would; a theme narrows it in CSS.
      def responsive(html)
        html.gsub(/<img\s+src="([^"]+)"/) do
          url = Regexp.last_match(1)
          set = @srcsets[url].presence || Nibble::Files.srcset_for_url(url)
          set ? %(<img src="#{url}" srcset="#{set}" sizes="100vw") : Regexp.last_match(0)
        end
      end

      def resolve_assets(text)
        ids = asset_ids(text)
        return text if ids.empty?

        found = Resolvers.find("asset").find(ids, scope: { "preset" => [ config("image_preset") ] })
                         .index_by { |summary| summary["id"] }
        text.gsub(ASSET_URL) do
          summary = found[Regexp.last_match(1)] or next Regexp.last_match(0)
          @srcsets[summary["url"]] = summary["srcset"]
          summary["url"]
        end
      end

      # A page is named by where it sits, not by its id, because the files it was written from say nothing else.
      def resolve_pages(text)
        text.gsub(PAGE_URL) do
          entry = page_at(Regexp.last_match(1))
          next "#" unless entry

          Dependencies.add("entry:#{entry.id}")
          "#{entry.uri}#{Regexp.last_match(2)}"
        end
      end

      def page_at(key)
        collection, *slugs = key.split("/")
        return nil if slugs.empty?

        slugs.reduce(nil) do |parent, slug|
          found = Records::Entry.kept.live.find_by(collection:, parent_id: parent&.id, slug:)
          break nil unless found

          found
        end
      end

      def transfer(value, ctx)
        return value unless ctx && value.present?

        value.to_s.gsub(ASSET_URL) { "nibble://asset/#{ctx.resolve('asset', Regexp.last_match(1))}" }
      end

      def asset_ids(value) = value.to_s.scan(ASSET_URL).flatten.uniq
    end
  end
end
