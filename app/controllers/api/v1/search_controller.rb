module Api
  module V1
    class SearchController < ActionController::API
      LIMIT = 12
      MINIMUM = 2

      def index
        query = params[:q].to_s.strip
        return render json: { results: [] } if query.length < MINIMUM

        found = Nibble::Search.search("site", query, locale: locale, limit: LIMIT)
        render json: { results: results(found.hits) }
      end

      private

      def locale = Nibble.config.default_locale.code

      def results(hits)
        loaded = hits.group_by(&:record_type).flat_map do |type, group|
          scope = Nibble::Records.model(type).where(id: group.map(&:record_id), deleted_at: nil)
          # A draft is in the index for the control panel's sake; it is nobody else's business.
          scope = scope.where(status: "published") if type == "entry"
          scope.to_a
        end.index_by { |record| [ record.record_type, record.id ] }

        hits.filter_map do |hit|
          record = loaded[[ hit.record_type, hit.record_id ]] or next
          { title: record.title.to_s, url: record.uri.to_s, group: group_for(record), snippet: hit.snippet.to_s }
        end
      end

      # A reader is looking for a page, not a collection, so a doc says which section it sits in.
      def group_for(record)
        if record.record_type == "entry" && record.collection == "documentation"
          record.parent&.title.presence || "Docs"
        elsif record.record_type == "entry"
          Nibble.schema.collection(record.collection)&.data&.dig("title").to_s
        else
          Nibble.schema.taxonomy(record.taxonomy)&.data&.dig("title").to_s
        end
      end
    end
  end
end
