module Nibble
  module Cp
    class TrashListing
      KINDS = %w[entries terms assets].freeze
      COLUMNS = [
        { "handle" => "title", "label" => "Title", "sortable" => false, "visible" => true, "type" => "text" },
        { "handle" => "group", "label" => "Type", "sortable" => false, "visible" => true, "type" => "text" },
        { "handle" => "deleted_at", "label" => "Deleted", "sortable" => false, "visible" => true, "type" => "date" },
        { "handle" => "controls", "label" => "", "sortable" => false, "visible" => true, "type" => "text" }
      ].freeze

      attr_reader :user, :params

      def initialize(user:, params: {})
        @user = user
        @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
      end

      def empty? = KINDS.none? { |name| scope(name).exists? }

      def props
        relation = scope(kind)
        total = relation.count
        records = relation.order(deleted_at: :desc, id: :desc).offset((page - 1) * per_page).limit(per_page).to_a
        {
          "handle" => "trash",
          "preference_key" => "trash",
          "label" => "deleted #{kind}",
          "rows" => records.map { |record| row(record) },
          "columns" => COLUMNS.map(&:dup),
          "filters" => [ { "handle" => "kind", "label" => "Kind", "type" => "select", "value" => kind,
                           "options" => KINDS.map { |name| { "value" => name, "label" => name.humanize } } } ],
          "search" => { "enabled" => false, "placeholder" => "", "value" => "" },
          "sort" => { "column" => "deleted_at", "direction" => "desc", "disabled_reason" => nil },
          "pagination" => { "page" => page, "per_page" => per_page, "total" => total,
                            "pages" => [ (total / per_page.to_f).ceil, 1 ].max, "per_page_options" => Listing::PER_PAGE_OPTIONS },
          "actions" => [],
          "presets" => [],
          "create" => nil
        }
      end

      private

      # Entries, terms and assets are separate tables with their own permissions, so one union can't be paged in SQL.
      # One kind shows at a time; with none chosen it is the first that has anything, entries first.
      def kind
        @kind ||= KINDS.include?(params[:kind]) ? params[:kind] : (KINDS.find { |name| scope(name).exists? } || KINDS.first)
      end

      def scope(name)
        case name
        when "entries" then entries
        when "terms" then terms
        else assets
        end
      end

      def entries
        trashed = Records::Entry.where.not(deleted_at: nil)
        collections = trashed.distinct.pluck(:collection)
        all = collections.select { |handle| Access.can?(user, "entries.#{handle}.delete") }
        own = (collections - all).select { |handle| Access.can?(user, "entries.#{handle}.delete_own") }
        trashed.where(collection: all)
          .or(trashed.where(collection: own, author_id: user.id))
          .or(trashed.where(collection: own, created_by_id: user.id))
      end

      def terms
        trashed = Records::Term.where.not(deleted_at: nil)
        trashed.where(taxonomy: trashed.distinct.pluck(:taxonomy).select { |handle| Access.can?(user, "terms.#{handle}.delete") })
      end

      def assets
        trashed = Records::Asset.where.not(deleted_at: nil)
        Access.can?(user, "assets.delete") ? trashed : trashed.none
      end

      def row(record)
        case record
        when Records::Entry then item(record, "entry", record.collection, record.title, record.uri)
        when Records::Term then item(record, "term", record.taxonomy, record.title, record.uri)
        else item(record, "asset", record.folder.presence || "assets", record.filename, nil)
        end
      end

      def item(record, type, group, title, uri)
        { "id" => record.id, "key" => "#{type}-#{record.id}", "type" => type, "group" => group, "title" => title, "uri" => uri,
          "deleted_at" => record.deleted_at.utc.iso8601, "referrers" => record.referrers.size, "actions" => [], "edit_url" => nil }
      end

      def page = [ params[:page].to_i, 1 ].max

      def per_page
        requested = params[:per_page].to_i
        Listing::PER_PAGE_OPTIONS.include?(requested) ? requested : (Nibble::UserPreferences.get(user, "listings.trash.per_page") || 25)
      end
    end
  end
end
