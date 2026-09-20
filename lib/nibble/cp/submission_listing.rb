module Nibble
  module Cp
    class SubmissionListing
      STATUS_COLUMN = { "handle" => "status", "label" => "Status", "sortable" => false, "visible" => true, "type" => "status" }.freeze
      DATE_COLUMN = { "handle" => "created_at", "label" => "Date", "sortable" => true, "visible" => true, "type" => "date" }.freeze
      VISIBLE_FIELDS = 3

      attr_reader :form, :user, :params

      def initialize(form, user:, params: {})
        @form = form
        @user = user
        @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
      end

      def preference_key = "forms_#{form.handle}"

      def props
        scope = relation
        total = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page).to_a
        {
          "handle" => "forms.#{form.handle}",
          "preference_key" => preference_key,
          "label" => "submissions",
          "rows" => records.map { |record| row(record) },
          "columns" => columns,
          "filters" => filters,
          "search" => { "enabled" => true, "placeholder" => "Search submissions…", "value" => params[:q].to_s },
          "sort" => { "column" => "created_at", "direction" => sort_direction, "disabled_reason" => nil },
          "pagination" => { "page" => page, "per_page" => per_page, "total" => total,
                            "pages" => [ (total / per_page.to_f).ceil, 1 ].max, "per_page_options" => Listing::PER_PAGE_OPTIONS },
          "actions" => actions,
          "presets" => [],
          "create" => nil
        }
      end

      def to_csv
        visible = columns.select { |column| column["visible"] }
        CSV.generate do |csv|
          csv << visible.map { |column| column["label"] }
          relation.find_each { |record| csv << visible.map { |column| csv_value(cell(record, column["handle"])) } }
        end
      end

      def relation
        scope = Records::FormSubmission.where(form: form.handle)
        scope = params[:status].present? ? scope.where(status: params[:status]) : scope.kept
        if params[:q].present?
          text = Arel::Nodes::NamedFunction.new("CAST", [ Records::FormSubmission.arel_table[:data].as("TEXT") ])
          scope = scope.where(Arel::Nodes::NamedFunction.new("LOWER", [ text ]).matches("%#{Records::FormSubmission.sanitize_sql_like(params[:q].to_s.downcase)}%"))
        end
        scope.order(created_at: sort_direction.to_sym, id: sort_direction.to_sym)
      end

      private

      def fields = @fields ||= form.fields.all.values

      def columns
        field_columns = fields.each_with_index.map do |field, index|
          { "handle" => field.handle, "label" => field.display, "sortable" => false, "visible" => index < VISIBLE_FIELDS,
            "type" => field.type == "files" ? "list" : Listing::TYPES.fetch(field.type, "text") }
        end
        saved = UserPreferences.get(user, "listings.#{preference_key}.columns").presence
        ([ DATE_COLUMN ] + field_columns + [ STATUS_COLUMN ]).map do |column|
          column.merge("visible" => saved ? saved.include?(column["handle"]) : column["visible"])
        end
      end

      def filters
        [ { "handle" => "status", "label" => "Status", "type" => "select", "value" => params[:status],
            "options" => Records::FormSubmission::STATUSES.map { |status| { "value" => status, "label" => status.humanize } } } ]
      end

      def row(record)
        cells = columns.to_h { |column| [ column["handle"], cell(record, column["handle"]) ] }
        cells.merge("id" => record.id, "actions" => row_actions, "edit_url" => "/admin/forms/#{form.handle}/submissions/#{record.id}",
                    "unread" => !record.read?)
      end

      def cell(record, handle)
        case handle
        when "created_at" then record.created_at.utc.iso8601
        when "status" then record.status
        else
          field = fields.find { |item| item.handle == handle }
          field && Forms.display_value(field, record.data[handle])
        end
      end

      def csv_value(value) = value.is_a?(Array) ? value.join(", ") : value

      def row_actions = can_delete? ? [ "delete" ] : []

      def can_delete? = Access.can?(user, "forms.#{form.handle}.delete")

      def actions
        return [] unless can_delete?

        [ { "handle" => "delete", "label" => "Delete", "confirm" => "Delete {count} submissions and their files?", "dangerous" => true,
            "bulk" => true, "fields" => [] } ]
      end

      def page = [ params[:page].to_i, 1 ].max

      def per_page
        requested = params[:per_page].to_i
        Listing::PER_PAGE_OPTIONS.include?(requested) ? requested : (UserPreferences.get(user, "listings.#{preference_key}.per_page") || 25)
      end

      def sort_direction = params[:dir].to_s == "asc" ? "asc" : "desc"
    end
  end
end
