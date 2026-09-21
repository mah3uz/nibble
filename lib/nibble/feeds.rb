module Nibble
  # Atom rather than RSS: one well-specified format, with dates that need no interpreting.
  module Feeds
    Source = Data.define(:handle, :item, :title, :limit)

    DEFAULT_LIMIT = 50

    class << self
      def sources(schema: Nibble.schema) = schema.collections.filter_map { |item| source(item) }

      def find(handle) = sources.find { |source| source.handle == handle }

      def feed_xml(source)
        entries = scope(source).map { |entry| entry_xml(entry) }
        document(title: source.title, path: "/feed-#{source.handle}.xml", updated: updated_at(scope(source)), entries:)
      end

      def site_xml
        records = sources.flat_map { |source| scope(source).to_a }.sort_by(&:published_at).reverse.first(DEFAULT_LIMIT)
        document(title: site_name, path: "/feed.xml", updated: records.first&.published_at, entries: records.map { |entry| entry_xml(entry) })
      end

      def any? = sources.any?

      private

      def site_name
        Records::GlobalSet.find_by(handle: "site", locale: Nibble.config.default_locale.code)&.values&.dig("name").presence || "Feed"
      end

      def source(item)
        config = item["feed"]
        return nil if config.blank? || item["route"].blank?

        config = {} unless config.is_a?(Hash)
        Source.new(handle: item.handle, item:, title: config["title"] || item["title"], limit: config["limit"] || DEFAULT_LIMIT)
      end

      def scope(source)
        Records::Entry.where(collection: source.item.handle, deleted_at: nil, status: "published")
          .where.not(uri: nil).order(published_at: :desc).limit(source.limit)
      end

      def updated_at(scope) = scope.maximum(:published_at)

      def entry_xml(entry)
        url = Presenter.url(entry.uri)
        summary = entry.values["excerpt"] || entry.values["description"]
        +"<entry><title>#{escape(entry.title)}</title><link href=\"#{escape(url)}\"/><id>#{escape(url)}</id>" \
          "<updated>#{(entry.published_at || entry.updated_at).utc.iso8601}</updated>" \
          "#{summary.present? ? "<summary>#{escape(summary)}</summary>" : ''}</entry>"
      end

      def document(title:, path:, updated:, entries:)
        %(<?xml version="1.0" encoding="UTF-8"?>\n<feed xmlns="http://www.w3.org/2005/Atom">) \
          "<title>#{escape(title)}</title><link href=\"#{escape(Presenter.url(path))}\" rel=\"self\"/>" \
          "<link href=\"#{escape(Presenter.url('/'))}\"/><id>#{escape(Presenter.url(path))}</id>" \
          "<updated>#{(updated || Time.current).utc.iso8601}</updated>#{entries.join}</feed>\n"
      end

      def escape(value) = ERB::Util.html_escape(value.to_s)
    end
  end
end
