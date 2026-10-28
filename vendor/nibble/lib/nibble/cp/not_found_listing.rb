module Nibble
  module Cp
    class NotFoundListing
      COLUMNS = [
        { "handle" => "path", "label" => "Path", "sortable" => false, "visible" => true, "type" => "text" },
        { "handle" => "hits", "label" => "Hits", "sortable" => true, "visible" => true, "type" => "number" },
        { "handle" => "last_seen_at", "label" => "Last seen", "sortable" => true, "visible" => true, "type" => "date" },
        { "handle" => "controls", "label" => "", "sortable" => false, "visible" => true, "type" => "text" }
      ].freeze
      SORTABLE = %w[hits last_seen_at].freeze

      attr_reader :user, :params

      def initialize(user:, params: {})
        @user = user
        @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
      end

      def any? = Records::NotFound.exists?

      def props
        scope = relation
        total = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page).to_a
        {
          "handle" => "not_found",
          "preference_key" => "not_found",
          "label" => "missing paths",
          "rows" => records.map { |record| row(record) },
          "columns" => COLUMNS.map(&:dup),
          "filters" => [],
          "search" => { "enabled" => true, "placeholder" => "Search paths…", "value" => params[:q].to_s },
          "sort" => { "column" => sort_column, "direction" => sort_direction, "disabled_reason" => nil },
          "pagination" => { "page" => page, "per_page" => per_page, "total" => total,
                            "pages" => [ (total / per_page.to_f).ceil, 1 ].max, "per_page_options" => Listing::PER_PAGE_OPTIONS },
          "actions" => [],
          "presets" => [],
          "create" => nil
        }
      end

      private

      def relation
        scope = Records::NotFound.all
        if params[:q].present?
          scope = scope.where(Records::NotFound.arel_table[:path].lower.matches("%#{Records::NotFound.sanitize_sql_like(params[:q].to_s.downcase)}%"))
        end
        scope.order(sort_column => sort_direction.to_sym, id: :asc)
      end

      def row(record)
        { "id" => record.id, "path" => record.path, "hits" => record.hits, "referrer" => record.referrer,
          "last_seen_at" => record.last_seen_at.utc.iso8601, "actions" => [], "edit_url" => nil }
      end

      def sort_column = SORTABLE.include?(params[:sort]) ? params[:sort] : "hits"

      def sort_direction = %w[asc desc].include?(params[:dir]) ? params[:dir] : "desc"

      def page = [ params[:page].to_i, 1 ].max

      def per_page
        requested = params[:per_page].to_i
        Listing::PER_PAGE_OPTIONS.include?(requested) ? requested : (Nibble::UserPreferences.get(user, "listings.not_found.per_page") || 25)
      end
    end
  end
end
