module Nibble
  module Cp
    class UserListing
      COLUMNS = [
        { "handle" => "email_address", "label" => "Email address", "sortable" => true, "visible" => true, "type" => "text" },
        { "handle" => "name", "label" => "Name", "sortable" => true, "visible" => true, "type" => "text" },
        { "handle" => "roles", "label" => "Roles", "sortable" => false, "visible" => true, "type" => "list" },
        { "handle" => "last_login_at", "label" => "Last sign-in", "sortable" => true, "visible" => true, "type" => "date" }
      ].freeze
      SORTABLE = COLUMNS.select { |column| column["sortable"] }.map { |column| column["handle"] }.freeze

      attr_reader :user, :params

      def initialize(user:, params: {})
        @user = user
        @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
      end

      def props
        scope = relation
        total = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page).includes(:roles).to_a
        {
          "handle" => "users",
          "preference_key" => "users",
          "label" => "users",
          "rows" => records.map { |record| row(record) },
          "columns" => COLUMNS.map(&:dup),
          "filters" => filters,
          "search" => { "enabled" => true, "placeholder" => "Search users…", "value" => params[:q].to_s },
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
        scope = ::User.all
        scope = scope.joins(:roles).where(roles: { handle: params[:role] }) if params[:role].present?
        if params[:q].present?
          term = "%#{::User.sanitize_sql_like(params[:q].to_s.downcase)}%"
          scope = scope.where("LOWER(email_address) LIKE :term OR LOWER(name) LIKE :term", term:)
        end
        scope.order(sort_column => sort_direction.to_sym, id: :asc)
      end

      def filters
        [ { "handle" => "role", "label" => "Role", "type" => "select", "value" => params[:role],
            "options" => ::Role.order(:title).map { |role| { "value" => role.handle, "label" => role.title } } } ]
      end

      def row(record)
        { "id" => record.id, "email_address" => record.email_address, "name" => record.name,
          "roles" => record.roles.map(&:title), "last_login_at" => record.last_login_at&.utc&.iso8601,
          "actions" => [], "edit_url" => "/cp/users/#{record.id}/edit", "you" => record.id == user.id,
          "editable" => user.admin? || !record.admin? }
      end

      def sort_column = SORTABLE.include?(params[:sort]) ? params[:sort] : "email_address"

      def sort_direction = params[:direction] == "desc" ? "desc" : "asc"

      def page = [ params[:page].to_i, 1 ].max

      def per_page
        requested = params[:per_page].to_i
        Listing::PER_PAGE_OPTIONS.include?(requested) ? requested : (UserPreferences.get(user, "listings.users.per_page") || 25)
      end
    end
  end
end
