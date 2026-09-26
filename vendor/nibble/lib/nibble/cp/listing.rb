module Nibble
  module Cp
    class Listing
      PER_PAGE_OPTIONS = [ 25, 50, 100 ].freeze
      TYPES = {
        "text" => "text", "textarea" => "text", "slug" => "code", "integer" => "number", "toggle" => "text",
        "select" => "text", "radio" => "text", "checkboxes" => "list", "date" => "date", "list" => "list",
        "assets" => "image", "entries" => "list", "terms" => "list", "link" => "text", "rich_text" => "text"
      }.freeze

      attr_reader :item, :user, :params

      def initialize(item, user:, params: {})
        @item = item
        @user = user
        @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
      end

      def entries? = item.kind == "collections"
      def files? = entries? && item["files"].present?
      def handle = "#{entries? ? 'collections' : 'taxonomies'}.#{item.handle}"
      def ability(action) = "#{entries? ? 'entries' : 'terms'}.#{item.handle}.#{action}"

      def to_csv
        visible = columns.select { |column| column["visible"] }
        CSV.generate do |csv|
          csv << visible.map { |column| column["label"] }
          (files? ? file_records : relation.find_each).each do |record|
            fields = record.blueprint_fields
            values = record.values
            csv << visible.map { |column| csv_value(cell(record, fields, values, column["handle"])) }
          end
        end
      end

      def props
        records, total = page_of_records
        {
          "handle" => handle,
          "preference_key" => preference_key,
          "label" => item["title"].to_s.downcase,
          "rows" => rows(records),
          "columns" => columns,
          "filters" => filters,
          "search" => { "enabled" => true, "placeholder" => "Search #{item['title'].downcase}…", "value" => params[:q].to_s },
          "sort" => { "column" => sort_column, "direction" => sort_direction, "disabled_reason" => nil },
          "pagination" => { "page" => page, "per_page" => per_page, "total" => total,
                            "pages" => [ (total / per_page.to_f).ceil, 1 ].max, "per_page_options" => PER_PAGE_OPTIONS },
          "actions" => actions,
          "presets" => presets,
          "create" => create_link
        }
      end

      private

      def schema = Nibble.schema
      def model = entries? ? Records::Entry : Records::Term
      def scope_column = entries? ? :collection : :taxonomy

      def blueprints = schema.blueprints_for(item).map { |blueprint| Blueprint.new(blueprint, schema:) }

      def listable_fields
        blueprints.flat_map { |blueprint| blueprint.fields.all.values }.uniq(&:handle).select(&:listable?)
      end

      def columns
        base = [ { "handle" => "title", "label" => "Title", "sortable" => true, "visible" => true, "type" => "title" } ]
        fields = listable_fields.reject { |field| field.handle == "title" }.map do |field|
          { "handle" => field.handle, "label" => field.display, "sortable" => false,
            "visible" => field.visible_on_listing?, "type" => TYPES.fetch(field.type, "text") }
        end
        tail = if entries?
          [ { "handle" => "status", "label" => "Status", "sortable" => false, "visible" => true, "type" => "status" },
            { "handle" => "published_at", "label" => "Date", "sortable" => true, "visible" => item["dated"] == true, "type" => "date" },
            { "handle" => "updated_at", "label" => "Updated", "sortable" => true, "visible" => false, "type" => "date" } ]
        else
          [ { "handle" => "updated_at", "label" => "Updated", "sortable" => true, "visible" => true, "type" => "date" } ]
        end
        all = (base + fields + tail).map { |column| column.merge("default" => column["visible"]) }
        saved = visible_columns or return all

        all.each_with_index.sort_by { |column, index| [ saved.index(column["handle"]) || saved.size, index ] }
           .map { |column, _| column.merge("visible" => saved.include?(column["handle"])) }
      end

      def visible_columns
        saved = Nibble::UserPreferences.get(user, "listings.#{preference_key}.columns")
        saved.presence
      end

      def preference_key = handle.tr(".", "_")

      def filters
        list = []
        if entries? && !files?
          list << { "handle" => "status", "label" => "Status", "type" => "select", "value" => params[:status],
                    "options" => Records::Entry::STATUSES.map { |status| { "value" => status, "label" => status.humanize } } }
        end
        if schema.blueprints_for(item).size > 1
          list << { "handle" => "blueprint", "label" => "Blueprint", "type" => "select", "value" => params[:blueprint],
                    "options" => schema.blueprints_for(item).map { |blueprint| { "value" => blueprint.handle, "label" => blueprint["title"] } } }
        end
        if Nibble.config.locales.size > 1
          list << { "handle" => "locale", "label" => "Locale", "type" => "select", "value" => params[:locale],
                    "options" => Nibble.config.locales.map { |locale| { "value" => locale.code, "label" => locale.code } } }
        end
        files? ? list : list + taxonomy_filters
      end

      def taxonomy_fields
        listable_fields.select { |field| field.type == "terms" }
      end

      def taxonomy_filters
        taxonomy_fields.filter_map do |field|
          handles = Array(field.get("taxonomies")).presence or next
          terms = Records::Term.kept.where(taxonomy: handles).order(:title)
          { "handle" => "term_#{field.handle}", "label" => field.display, "type" => "multi_select",
            "value" => Array(params[:"term_#{field.handle}"]),
            "options" => terms.map { |term| { "value" => term.id.to_s, "label" => term.title } } }
        end
      end

      def relation
        scope = model.kept.where(scope_column => item.handle)
        scope = scope.where(status: params[:status]) if entries? && params[:status].present?
        scope = scope.where(blueprint: params[:blueprint]) if params[:blueprint].present?
        scope = scope.where(locale: params[:locale]) if params[:locale].present?
        scope = scope.where(model.arel_table[:title].lower.matches("%#{model.sanitize_sql_like(params[:q].to_s.downcase)}%")) if params[:q].present?
        scope = scope.where(id: Records::Entry.where(author_id: user.id)) if only_own?
        taxonomy_fields.each do |field|
          ids = Array(params[:"term_#{field.handle}"]).compact_blank
          next if ids.empty?

          scope = scope.where(id: Records::Relation.where(source_type: model.record_type, field: field.handle, target_id: ids).select(:source_id))
        end
        scope.order(sort_column => sort_direction.to_sym, id: :asc)
      end

      def only_own? = entries? && !Access.can?(user, ability("view")) && Access.can?(user, ability("edit_own"))

      def page_of_records
        if files?
          list = file_records
          return [ list.slice((page - 1) * per_page, per_page) || [], list.size ]
        end

        scope = relation
        [ scope.offset((page - 1) * per_page).limit(per_page).to_a, scope.count ]
      end

      # A folder is read from the index, which is small and in memory, so it is filtered here rather than queried.
      def file_records
        pages = Files.index.of(item.handle)
        pages = pages.select { |record| record.blueprint == params[:blueprint] } if params[:blueprint].present?
        pages = pages.select { |record| record.locale == params[:locale] } if params[:locale].present?
        pages = pages.select { |record| record.title.downcase.include?(params[:q].to_s.downcase) } if params[:q].present?
        sorted, unsorted = pages.partition { |record| !file_sort_value(record).nil? }
        sorted = sorted.sort_by { |record| [ file_sort_value(record), record.title ] }
        sorted.reverse! if sort_direction == "desc"
        sorted + unsorted.sort_by(&:title)
      end

      def file_sort_value(record)
        case sort_column
        when "title" then record.title.downcase
        when "published_at" then record.published_at
        when "position" then record.position
        end
      end

      def page = [ params[:page].to_i, 1 ].max
      def per_page = PER_PAGE_OPTIONS.include?(params[:per_page].to_i) ? params[:per_page].to_i : (Nibble::UserPreferences.get(user, "listings.#{preference_key}.per_page") || 25)

      def sort_column
        requested = params[:sort].to_s
        return requested if columns.any? { |column| column["handle"] == requested && column["sortable"] }

        default = item["sort"].to_s.split(":").first
        model.column_names.include?(default) ? default : "updated_at"
      end

      def sort_direction
        requested = params[:dir].to_s
        return requested if %w[asc desc].include?(requested)

        item["sort"].to_s.split(":").last == "asc" ? "asc" : "desc"
      end

      def rows(records)
        handles = columns.select { |column| column["visible"] }.map { |column| column["handle"] } | [ "title" ]
        Resolvers.preloading(references(records, handles)) { records.map { |record| row(record, handles) } }
      end

      def references(records, handles)
        records.flat_map do |record|
          fields = record.blueprint_fields
          values = record.values
          handles.flat_map do |handle|
            fieldtype = fields.get(handle)&.with_value(values[handle])&.fieldtype
            next [] unless fieldtype.is_a?(Fieldtypes::Relationship)

            fieldtype.relations(values[handle]).map { |type, id| [ type, fieldtype.scope, id ] }
          end
        end
      end

      def row(record, handles)
        fields = record.blueprint_fields
        values = record.values
        cells = handles.index_with { |handle| cell(record, fields, values, handle) }
        cells.merge(
          "id" => record.id,
          "actions" => row_actions(record),
          "edit_url" => edit_url(record)
        )
      end

      def cell(record, fields, values, handle)
        case handle
        when "title" then record.title.to_s.presence || "Untitled"
        when "status" then record.respond_to?(:status) ? record.status : nil
        when "published_at" then record.try(:published_at)&.utc&.iso8601
        when "updated_at" then record.updated_at&.utc&.iso8601
        else
          field = fields.get(handle) or return nil
          return thumbnails(field.with_value(values[handle])) if field.type == "assets"

          index_value(field.with_value(values[handle]))
        end
      end

      def thumbnails(field)
        field.fieldtype.pre_process_index(field.value).map { |asset| asset.slice("thumbnail", "title", "url") }
      end

      def index_value(field)
        value = field.fieldtype.pre_process_index(field.value)
        case value
        when Hash then value["title"] || value["date"] || value["url"] || value.values.first
        when Array then value.map { |entry| entry.is_a?(Hash) ? entry["title"] || entry["url"] : entry.to_s }
        else value
        end
      end

      def edit_url(record)
        base = entries? ? "/cp/collections/#{item.handle}/entries" : "/cp/taxonomies/#{item.handle}/terms"
        "#{base}/#{record.id}/edit"
      end

      def row_actions(record)
        available = []
        return available if files?

        available << "publish" if entries? && Access.can?(user, ability("publish"), record) && record.status != "published"
        available << "unpublish" if entries? && Access.can?(user, ability("publish"), record) && %w[published scheduled].include?(record.status)
        available << "move" if entries? && item["structure"].is_a?(Hash) && Access.can?(user, ability("edit"), record)
        available.concat(assignable_taxonomies.keys.map { |handle| "assign_#{handle}" }) if entries? && Access.can?(user, ability("edit"), record)
        available << "trash" if Access.can?(user, ability("delete"), record)
        available
      end

      def csv_value(value)
        case value
        when Array then value.join(", ")
        when Hash then value["text"] || value.values.compact.join(" ")
        else value
        end
      end

      # The file is the truth, so publishing, moving or trashing a row would change nothing anyone can see.
      def actions
        return [] if item["files"].present?

        list = []
        if entries? && Access.can?(user, ability("publish"))
          list << action("publish", "Publish", confirm: nil)
          list << action("unpublish", "Unpublish", confirm: "Unpublish the selected entries?")
        end
        list << move_action if entries? && item["structure"].is_a?(Hash) && Access.can?(user, ability("edit"))
        list.concat(assign_actions) if entries? && Access.can?(user, ability("edit"))
        list << action("trash", "Move to trash", confirm: "Move the selected items to the trash?", dangerous: true) if Access.can?(user, ability("delete"))
        list
      end

      # Reka's Select rejects an empty value.
      TOP_LEVEL = "root"

      def assignable_taxonomies
        @assignable_taxonomies ||= begin
          declared = blueprints.flat_map { |blueprint| blueprint.fields.all.values }.select { |field| field.type == "terms" }
            .to_h { |field| [ field.handle, Array(field.get("taxonomies")) ] }
          Array(item["taxonomies"]).to_h { |handle| [ handle, [ handle ] ] }.merge(declared)
        end
      end

      def assign_actions
        assignable_taxonomies.filter_map do |handle, taxonomies|
          terms = Records::Term.kept.where(taxonomy: taxonomies).order(:title).to_a
          next if terms.empty?

          title = schema.taxonomy(taxonomies.first)&.[]("title").to_s.presence || handle.humanize
          label = "Add #{title.singularize.downcase}"
          action("assign_#{handle}", label, confirm: "#{label} to {count} entries").merge(
            "fields" => [ { "handle" => "term_ids", "label" => title.singularize,
                            "options" => terms.map { |term| { "value" => term.id.to_s, "label" => term.title.to_s } } } ]
          )
        end
      end

      def move_action
        parents = model.kept.where(collection: item.handle).order(:position, :title).map { |entry| { "value" => entry.id.to_s, "label" => entry.title.to_s } }
        action("move", "Move", confirm: "Move {count} entries under…").merge(
          "fields" => [ { "handle" => "parent_id", "label" => "New parent", "options" => [ { "value" => TOP_LEVEL, "label" => "Top level" }, *parents ] } ]
        )
      end

      def action(handle, label, confirm:, dangerous: false)
        { "handle" => handle, "label" => label, "confirm" => confirm, "dangerous" => dangerous, "bulk" => true, "fields" => [] }
      end

      def presets
        saved = Array(Nibble::UserPreferences.get(user, "listings.#{preference_key}.presets"))
        built_in = entries? && !files? ? [ { "handle" => "drafts", "label" => "Drafts", "query" => { "status" => "draft" }, "built_in" => true } ] : []
        built_in + saved.map { |preset| preset.merge("built_in" => false) }
      end

      def create_link
        return nil if files? || !Access.can?(user, ability("create"))

        label = "New #{item['title'].to_s.singularize.downcase}"
        url = entries? ? "/cp/collections/#{item.handle}/entries/new" : "/cp/taxonomies/#{item.handle}/terms/new"
        { "label" => label, "url" => url }
      end
    end
  end
end
