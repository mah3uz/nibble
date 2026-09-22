module Nibble
  module Sitemaps
    Source = Data.define(:handle, :item, :model, :scope_column, :priority, :changefreq)

    class << self
      def sources(schema: Nibble.schema)
        collections = schema.collections.map { |item| source(item, Records::Entry, :collection) }
        taxonomies = schema.taxonomies.map { |item| source(item, Records::Term, :taxonomy) }
        (collections + taxonomies).compact
      end

      def find(handle) = sources.find { |source| source.handle == handle }

      def index_xml
        entries = sources.map do |source|
          lastmod = scope(source).maximum(:updated_at)
          "<sitemap><loc>#{escape(Presenter.url("/sitemap-#{source.handle}.xml"))}</loc>#{lastmod ? "<lastmod>#{lastmod.utc.iso8601}</lastmod>" : ''}</sitemap>"
        end
        %(<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">#{entries.join}</sitemapindex>\n)
      end

      def urlset_xml(source)
        urls = +""
        records = (scope(source).where.not(uri: nil).to_a + file_pages(source)).sort_by(&:uri)
        records.each do |record|
          next if record.values.to_h.dig("seo", "noindex")

          lastmod = (record.updated_at || Time.current).utc.iso8601
          urls << "<url><loc>#{escape(Presenter.url(record.uri))}</loc><lastmod>#{lastmod}</lastmod>" \
                  "<changefreq>#{source.changefreq}</changefreq><priority>#{source.priority}</priority></url>"
        end
        %(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">#{urls}</urlset>\n)
      end

      def robots_txt
        return "User-agent: *\nDisallow: /\n" unless Seo.indexable?

        "User-agent: *\nAllow: /\n\nSitemap: #{Presenter.url('/sitemap.xml')}\n"
      end

      private

      def source(item, model, scope_column)
        config = item["sitemap"].to_h
        return nil if config["enabled"] == false || item["route"].blank?

        prefix = scope_column == :collection ? "" : "taxonomy-"
        Source.new(handle: "#{prefix}#{item.handle}", item:, model:, scope_column:, priority: config["priority"] || 0.5, changefreq: config["changefreq"] || "weekly")
      end

      def file_pages(source)
        source.scope_column == :collection ? Files.index.of(source.item.handle) : []
      end

      def scope(source)
        relation = source.model.where(source.scope_column => source.item.handle, deleted_at: nil)
        source.model == Records::Entry ? relation.where(status: "published") : relation
      end

      def escape(value) = ERB::Util.html_escape(value)
    end
  end
end
