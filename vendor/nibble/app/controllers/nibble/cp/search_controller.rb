module Nibble
  module Cp
    class SearchController < BaseController
      LIMIT = 5

      def index
        render json: { groups: groups }
      end

      private

      def groups
        term = params[:q].to_s.strip.downcase
        return [] if term.blank?

        (collection_groups(term) + taxonomy_groups(term)).compact
      end

      def collection_groups(term)
        Nibble.schema.collections.filter_map do |collection|
          next unless Nibble::Access.can?(Nibble::Current.user, "entries.#{collection.handle}.view")

          records = matching(Nibble::Records::Entry.kept.where(collection: collection.handle), term)
          group(collection["title"], records.map do |entry|
            item(entry.title, entry.uri, "/cp/collections/#{collection.handle}/entries/#{entry.id}/edit", "collection", entry.status)
          end)
        end
      end

      def taxonomy_groups(term)
        Nibble.schema.taxonomies.filter_map do |taxonomy|
          next unless Nibble::Access.can?(Nibble::Current.user, "terms.#{taxonomy.handle}.view")

          records = matching(Nibble::Records::Term.kept.where(taxonomy: taxonomy.handle), term)
          group(taxonomy["title"], records.map do |record|
            item(record.title, record.uri, "/cp/taxonomies/#{taxonomy.handle}/terms/#{record.id}/edit", "taxonomy")
          end)
        end
      end

      def matching(scope, term)
        like = "%#{Nibble::Records::Entry.sanitize_sql_like(term)}%"
        scope.where("LOWER(title) LIKE :like OR LOWER(uri) LIKE :like", like: like)
          .where(locale: Nibble.config.default_locale.code).order(updated_at: :desc).limit(LIMIT)
      end

      def group(label, items) = items.empty? ? nil : { label: label, items: items }
      def item(title, subtitle, url, icon, status = nil) = { title: title, subtitle: subtitle, url: url, icon: icon, status: status }
    end
  end
end
