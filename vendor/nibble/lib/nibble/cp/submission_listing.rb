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
        every = all_columns
        CSV.generate do |csv|
          csv << CsvCells.row(every.map { |column| column["label"] })
          relation.find_each { |record| csv << CsvCells.row(every.map { |column| csv_value(cell(record, column["handle"])) }) }
        end
      end

      def spam_count = @spam_count ||= Records::FormSubmission.where(form: form.handle, status: "spam").count

      def relation
        scope = Records::FormSubmission.where(form: form.handle)
        scope = params[:status].present? ? scope.where(status: params[:status]) : scope.kept
        scope = scope.handled if params[:handling] == "handled"
        scope = scope.unhandled if params[:handling] == "new"
        if params[:q].present?
          text = Arel::Nodes::NamedFunction.new("CAST", [ Records::FormSubmission.arel_table[:data].as("TEXT") ])
          scope = scope.where(Arel::Nodes::NamedFunction.new("LOWER", [ text ]).matches("%#{Records::FormSubmission.sanitize_sql_like(params[:q].to_s.downcase)}%"))
        end
        scope.order(created_at: sort_direction.to_sym, id: sort_direction.to_sym)
      end

      private

      def fields = @fields ||= form.fields.all.values.reject(&:display_only?)

      def all_columns
        field_columns = fields.each_with_index.map do |field, index|
          { "handle" => field.handle, "label" => field.display, "sortable" => false, "visible" => index < VISIBLE_FIELDS,
            "type" => field.type == "files" ? "list" : Listing::TYPES.fetch(field.type, "text") }
        end
        [ DATE_COLUMN ] + field_columns + [ STATUS_COLUMN ]
      end

      def columns
        saved = Nibble::UserPreferences.get(user, "listings.#{preference_key}.columns").presence
        all_columns.map do |column|
          column.merge("visible" => saved ? saved.include?(column["handle"]) : column["visible"])
        end
      end

      def filters
        options = Records::FormSubmission::STATUSES.map do |status|
          { "value" => status, "label" => status == "spam" ? "Spam (#{spam_count})" : status.humanize }
        end
        [ { "handle" => "status", "label" => "Status", "type" => "select", "value" => params[:status], "all_label" => "All but spam", "options" => options },
          { "handle" => "handling", "label" => "Handling", "type" => "select", "value" => params[:handling], "all_label" => "New and handled",
            "options" => [ { "value" => "new", "label" => "New" }, { "value" => "handled", "label" => "Handled" } ] } ]
      end

      def row(record)
        cells = columns.to_h { |column| [ column["handle"], cell(record, column["handle"]) ] }
        cells.merge("id" => record.id, "actions" => row_actions, "edit_url" => "/cp/forms/#{form.handle}/submissions/#{record.id}",
                    "unread" => !record.read?, "handled" => record.handled?)
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

      def row_actions = (can_edit? ? %w[mark_handled mark_new mark_unread] : []) + (can_delete? ? [ "delete" ] : [])

      def can_edit? = Access.can?(user, "forms.#{form.handle}.edit")

      def can_delete? = Access.can?(user, "forms.#{form.handle}.delete")

      def actions
        handling = can_edit? ? [ { "handle" => "mark_handled", "label" => "Mark handled", "bulk" => true, "fields" => [] },
                                 { "handle" => "mark_new", "label" => "Mark not handled", "bulk" => true, "fields" => [] },
                                 { "handle" => "mark_unread", "label" => "Mark unread", "bulk" => true, "fields" => [] } ] : []
        return handling unless can_delete?

        handling + [ { "handle" => "delete", "label" => "Delete", "confirm" => "Delete {count} submissions and their files?", "dangerous" => true,
            "bulk" => true, "fields" => [] } ]
      end

      def page = [ params[:page].to_i, 1 ].max

      def per_page
        requested = params[:per_page].to_i
        Listing::PER_PAGE_OPTIONS.include?(requested) ? requested : (Nibble::UserPreferences.get(user, "listings.#{preference_key}.per_page") || 25)
      end

      def sort_direction = params[:dir].to_s == "asc" ? "asc" : "desc"
    end
  end
end
