module Nibble
  module Cp
    class AssetListing
      PER_PAGE_OPTIONS = Listing::PER_PAGE_OPTIONS
      SORTABLE = %w[filename size updated_at].freeze
      ROOT = "root"

      attr_reader :user, :params

      def initialize(user:, params: {})
        @user = user
        @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
      end

      def folder = params[:folder].to_s.delete_prefix("/").delete_suffix("/")
      def searching? = params[:q].present?

      def props
        assets, total = page_of_assets
        usage = Records::Relation.where(target_type: "asset", target_id: assets.map(&:id)).group(:target_id).count
        {
          "handle" => "assets",
          "preference_key" => "assets",
          "label" => "assets",
          "rows" => assets.map { |asset| row(asset, usage[asset.id].to_i) },
          "columns" => columns,
          "filters" => filters,
          "search" => { "enabled" => true, "placeholder" => "Search…", "value" => params[:q].to_s },
          "sort" => { "column" => sort_column, "direction" => sort_direction, "disabled_reason" => nil },
          "pagination" => { "page" => page, "per_page" => per_page, "total" => total,
                            "pages" => [ (total / per_page.to_f).ceil, 1 ].max, "per_page_options" => PER_PAGE_OPTIONS },
          "actions" => [],
          "presets" => [],
          "create" => nil
        }
      end

      def folders
        return [] if searching?

        parent = folder.empty? ? nil : Records::AssetFolder.find_by(path: folder)
        return [] if folder.present? && parent.nil?

        Records::AssetFolder.where(parent_id: parent&.id).order(:path).map { |item| { "path" => item.path, "name" => item.name } }
      end

      def folder_options
        [ { "value" => ROOT, "label" => "Root" } ] +
          Records::AssetFolder.order(:path).map { |item| { "value" => item.path, "label" => item.path } }
      end

      def row(asset, usage_count)
        {
          "id" => asset.id, "filename" => asset.filename, "title" => asset.display_title, "kind" => asset.kind,
          "extension" => asset.extension, "thumbnail" => asset.thumbnail_url, "url" => asset.url,
          "size" => asset.size, "updated_at" => asset.updated_at.utc.iso8601, "width" => asset.width, "height" => asset.height,
          "duration" => asset.duration, "alt" => asset.alt, "folder" => asset.folder, "usage_count" => usage_count,
          "edit_url" => "/cp/media?#{{ folder: asset.folder.presence, asset: asset.id }.compact.to_query}",
          "actions" => []
        }
      end

      private

      def relation
        scope = Records::Asset.kept
        scope = scope.where(folder:) unless searching?
        if searching?
          pattern = "%#{Records::Asset.sanitize_sql_like(params[:q].to_s.downcase)}%"
          table = Records::Asset.arel_table
          scope = scope.where(table[:filename].lower.matches(pattern).or(table[:title].lower.matches(pattern)).or(table[:alt].lower.matches(pattern)))
        end
        scope = scope.where(kind: params[:kind]) if params[:kind].present?
        types = params[:types].to_s.split(",").map { |type| type.strip.downcase.delete_prefix(".") }.compact_blank
        if types.any?
          scope = scope.where(types.map { |type| Records::Asset.arel_table[:filename].lower.matches("%.#{Records::Asset.sanitize_sql_like(type)}") }.reduce(:or))
        end
        scope = scope.where.not(id: Records::Relation.where(target_type: "asset").select(:target_id)) if params[:usage] == "unused"
        scope = scope.where(id: Records::Relation.where(target_type: "asset").select(:target_id)) if params[:usage] == "used"
        scope
      end

      def page_of_assets
        scope = relation
        total = scope.count
        [ scope.order(sort_column => sort_direction, id: :asc).offset((page - 1) * per_page).limit(per_page).to_a, total ]
      end

      def columns
        [
          { "handle" => "filename", "label" => "File", "sortable" => true, "visible" => true, "type" => "text" },
          { "handle" => "size", "label" => "Size", "sortable" => true, "visible" => true, "type" => "number" },
          { "handle" => "updated_at", "label" => "Last Modified", "sortable" => true, "visible" => true, "type" => "date" },
          { "handle" => "width", "label" => "Width", "sortable" => false, "visible" => true, "type" => "number" },
          { "handle" => "height", "label" => "Height", "sortable" => false, "visible" => true, "type" => "number" },
          { "handle" => "duration", "label" => "Duration", "sortable" => false, "visible" => true, "type" => "number" }
        ]
      end

      def filters
        [
          { "handle" => "kind", "label" => "Type", "type" => "select", "value" => params[:kind].presence,
            "options" => [ *Assets::KINDS.keys, "file" ].map { |kind| { "value" => kind, "label" => kind == "svg" ? "SVG" : kind.capitalize } } },
          { "handle" => "usage", "label" => "Usage", "type" => "select", "value" => params[:usage].presence,
            "options" => [ { "value" => "used", "label" => "Used" }, { "value" => "unused", "label" => "Unused" } ] }
        ]
      end

      def page = [ params[:page].to_i, 1 ].max

      def per_page
        requested = params[:per_page].to_i
        return requested if PER_PAGE_OPTIONS.include?(requested)

        saved = Nibble::UserPreferences.get(user, "listings.assets.per_page")
        PER_PAGE_OPTIONS.include?(saved) ? saved : PER_PAGE_OPTIONS.first
      end

      def sort_column = SORTABLE.include?(params[:sort]) ? params[:sort] : "filename"
      def sort_direction = params[:dir] == "desc" ? "desc" : "asc"
    end
  end
end
