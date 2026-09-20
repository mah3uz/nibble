module Nibble
  module Routing
    Match = Data.define(:kind, :record, :taxonomy, :locale, :template, :redirect) do
      def self.redirect(to) = new(kind: :redirect, record: nil, taxonomy: nil, locale: nil, template: nil, redirect: to)
    end

    class << self
      def resolve(path, schema: Nibble.schema)
        find(path, schema) || canonical(path, schema)
      end

      def locale_for(path)
        prefixed = Nibble.config.locales.select { |locale| locale.url_prefix.present? }
        match = prefixed.find { |locale| path == Uris.normalize(locale.url_prefix) || path.start_with?("#{Uris.normalize(locale.url_prefix)}/") }
        (match || Nibble.config.default_locale).code
      end

      private

      def find(path, schema)
        if (entry = Records::Entry.live.find_by(uri: path))
          return Match.new(kind: :entry, record: entry, taxonomy: nil, locale: entry.locale, template: entry_template(entry), redirect: nil)
        end
        if (term = Records::Term.kept.find_by(uri: path))
          template = term.taxonomy_item["template"] || "taxonomies/show"
          return Match.new(kind: :term, record: term, taxonomy: term.taxonomy_item, locale: term.locale, template:, redirect: nil)
        end
        taxonomy = schema.taxonomies.find { |item| item["index_route"] && Uris.normalize(item["index_route"]) == path }
        return nil unless taxonomy

        Match.new(kind: :taxonomy, record: nil, taxonomy:, locale: locale_for(path), template: taxonomy["index_template"] || "taxonomies/index", redirect: nil)
      end

      def canonical(path, schema)
        normalized = Uris.normalize(path.downcase)
        return nil if normalized == path

        find(normalized, schema) && Match.redirect(normalized)
      end

      def entry_template(entry)
        entry.template.presence || entry.blueprint_item["template"] || entry.collection_item["template"] || "default"
      end
    end
  end
end
