module Nibble
  module Cp
    class LinkSuggestionsController < BaseController
      LIMIT = 5

      def index
        render json: { suggestions: suggestions }
      end

      private

      def suggestions
        term = params[:q].to_s.strip.delete_prefix("/").downcase

        Nibble.schema.collections.filter_map do |collection|
          next unless Nibble::Access.can?(Nibble::Current.user, "entries.#{collection.handle}.view")

          entries(collection, term).map do |entry|
            { title: entry.title, path: entry.uri, type: collection["title"].to_s.singularize.downcase,
              status: entry.status }
          end
        end.flatten
      end

      def entries(collection, term)
        scope = Nibble::Records::Entry.kept.where(collection: collection.handle, locale: Nibble.config.default_locale.code)
          .where.not(uri: nil).order(updated_at: :desc).limit(LIMIT)
        return scope if term.blank?

        scope.where("LOWER(uri) LIKE :term OR LOWER(title) LIKE :term",
                    term: "%#{Nibble::Records::Entry.sanitize_sql_like(term)}%")
      end
    end
  end
end
