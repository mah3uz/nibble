module Nibble
  module Cp
    class RedirectListing
      STATUS_LABELS = { 301 => "Permanent", 302 => "Temporary", 307 => "Temporary, same method", 308 => "Permanent, same method" }.freeze
      COLUMNS = [
        { "handle" => "from", "label" => "From", "sortable" => true, "visible" => true, "type" => "text" },
        { "handle" => "to", "label" => "To", "sortable" => false, "visible" => true, "type" => "text" },
        { "handle" => "status", "label" => "Status", "sortable" => false, "visible" => true, "type" => "text" },
        { "handle" => "source", "label" => "Added", "sortable" => false, "visible" => true, "type" => "text" },
        { "handle" => "hits", "label" => "Hits", "sortable" => true, "visible" => true, "type" => "number" },
        { "handle" => "last_hit_at", "label" => "Last hit", "sortable" => true, "visible" => true, "type" => "date" }
      ].freeze
      SORTABLE = COLUMNS.select { |column| column["sortable"] }.map { |column| column["handle"] }.freeze

      def self.status_label(status) = "#{STATUS_LABELS.fetch(status)} (#{status})"

      attr_reader :user, :params

      def initialize(user:, params: {})
        @user = user
        @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
      end

      def props
        scope = relation
        total = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page).to_a
        {
          "handle" => "redirects",
          "preference_key" => "redirects",
          "label" => "redirects",
          "rows" => records.map { |record| row(record) },
          "columns" => columns,
          "filters" => [],
          "search" => { "enabled" => true, "placeholder" => "Search redirects…", "value" => params[:q].to_s },
          "sort" => { "column" => sort_column, "direction" => sort_direction, "disabled_reason" => nil },
          "pagination" => { "page" => page, "per_page" => per_page, "total" => total,
                            "pages" => [ (total / per_page.to_f).ceil, 1 ].max, "per_page_options" => Listing::PER_PAGE_OPTIONS },
          "actions" => [ { "handle" => "delete", "label" => "Delete", "confirm" => "Delete the selected redirects?", "dangerous" => true,
                           "bulk" => true, "fields" => [] } ],
          "presets" => [],
          "create" => nil
        }
      end

      private

      def relation
        table = Records::Redirect.arel_table
        scope = Records::Redirect.all
        if params[:q].present?
          term = "%#{Records::Redirect.sanitize_sql_like(params[:q].to_s)}%"
          scope = scope.where(table[:from].matches(term, "\\").or(table[:to].matches(term, "\\")))
        end
        scope.order(sort_column => sort_direction.to_sym, id: :asc)
      end

      def columns
        saved = Nibble::UserPreferences.get(user, "listings.redirects.columns").presence
        COLUMNS.map { |column| column.merge("visible" => saved ? saved.include?(column["handle"]) : column["visible"]) }
      end

      def row(record)
        { "id" => record.id, "from" => record.from, "to" => record.to, "status" => self.class.status_label(record.status),
          "status_code" => record.status, "source" => record.source, "hits" => record.hits,
          "last_hit_at" => record.last_hit_at&.utc&.iso8601, "actions" => [ "delete" ], "edit_url" => nil }
      end

      def sort_column = SORTABLE.include?(params[:sort]) ? params[:sort] : "from"

      def sort_direction = params[:dir] == "desc" ? "desc" : "asc"

      def page = [ params[:page].to_i, 1 ].max

      def per_page
        requested = params[:per_page].to_i
        Listing::PER_PAGE_OPTIONS.include?(requested) ? requested : (Nibble::UserPreferences.get(user, "listings.redirects.per_page") || 25)
      end
    end
  end
end
