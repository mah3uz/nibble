module Admin
  class CollectionsController < BaseController
    VIEWS = %w[list tree calendar].freeze

    def show
      collection = Nibble.schema.collection(params[:handle]) or raise ActiveRecord::RecordNotFound
      authorize!("entries.#{collection.handle}.view")
      structured = collection["structure"].is_a?(Hash)
      dated = collection["dated"] == true
      view = requested_view(structured, dated)

      props = {
        collection: { handle: collection.handle, title: collection["title"], icon: collection["icon"] || "collections", structured:, dated:, view:,
                      views: [ "list", ("tree" if structured), ("calendar" if dated) ].compact,
                      blueprints: Nibble.schema.blueprints_for(collection).map do |item|
                        { title: item["title"], url: "/admin/blueprints/#{collection.handle}.#{item.handle}" }
                      end },
        create: create_link(collection)
      }
      listing = Nibble::Cp::Listing.new(collection, user: Current.user, params:)
      return send_csv(collection, listing) if request.format.csv?

      props[:listing] = listing.props if view == "list"
      props[:tree] = tree(collection) if view == "tree"
      props[:calendar] = calendar(collection) if view == "calendar"

      render inertia: "admin/collections/Index", props:
    end

    private

    def send_csv(collection, listing)
      send_data listing.to_csv, filename: "#{collection.handle}-#{Date.current.iso8601}.csv", type: "text/csv"
    end

    def create_link(collection)
      return nil if collection["files"].present? || !Nibble::Access.can?(Current.user, "entries.#{collection.handle}.create")

      { label: "New #{collection['title'].to_s.singularize.downcase}", url: "/admin/collections/#{collection.handle}/entries/new" }
    end

    def requested_view(structured, dated)
      requested = params[:view].to_s
      return requested if VIEWS.include?(requested) && (requested != "tree" || structured) && (requested != "calendar" || dated)

      "list"
    end

    def tree(collection)
      return file_nodes(collection) if collection["files"].present?

      entries = Nibble::Records::Entry.kept.where(collection: collection.handle, locale: locale).order(:position, :title)
      by_parent = entries.group_by(&:parent_id)
      build_nodes(by_parent, nil, collection)
    end

    # The folders are the structure: a page sits under its folder's index.md, not under a parent anyone chose.
    def file_nodes(collection, parent_key = nil, by_parent = nil)
      by_parent ||= file_pages(collection).group_by(&:parent_key)
      by_parent.fetch(parent_key, []).sort_by { |page| [ page.position || Float::INFINITY, page.title ] }.map do |page|
        {
          id: page.id, title: page.title, status: page.status, uri: page.uri, parent_id: nil,
          edit_url: "/admin/collections/#{collection.handle}/entries/#{page.id}/edit",
          children: page.root? ? [] : file_nodes(collection, page.key, by_parent)
        }
      end
    end

    def file_pages(collection) = Nibble::Files.index.of(collection.handle).select { |page| page.locale == locale }

    def build_nodes(by_parent, parent_id, collection)
      by_parent.fetch(parent_id, []).map do |entry|
        {
          id: entry.id, title: entry.title, status: entry.status, uri: entry.uri, parent_id: entry.parent_id,
          edit_url: "/admin/collections/#{collection.handle}/entries/#{entry.id}/edit",
          children: build_nodes(by_parent, entry.id, collection)
        }
      end
    end

    def calendar(collection)
      scale = params[:scale] == "week" ? "week" : "month"
      date = parse_date(params[:date])
      from, to = scale == "week" ? [ date.beginning_of_week(:sunday), date.end_of_week(:sunday) ] : month_range(date)
      range = from.beginning_of_day..to.end_of_day
      entries = if collection["files"].present?
        file_pages(collection).select { |page| page.published_at && range.cover?(page.published_at) }.sort_by(&:published_at)
      else
        Nibble::Records::Entry.kept.where(collection: collection.handle, locale: locale).where(published_at: range).order(:published_at)
      end

      {
        scale:, date: date.iso8601, from: from.iso8601, to: to.iso8601,
        title: scale == "week" ? week_title(from, to) : date.strftime("%B %Y"),
        today: Date.current.iso8601,
        days: entries.group_by { |entry| entry.published_at.in_time_zone.to_date.iso8601 }.transform_values do |list|
          list.map do |entry|
            { id: entry.id, title: entry.title, status: entry.status,
              hour: entry.published_at.in_time_zone.hour,
              time: entry.published_at.in_time_zone.strftime("%-l:%M%P"),
              edit_url: "/admin/collections/#{collection.handle}/entries/#{entry.id}/edit" }
          end
        end
      }
    end

    def month_range(date)
      [ date.beginning_of_month.beginning_of_week(:sunday), date.end_of_month.end_of_week(:sunday) ]
    end

    def week_title(from, to)
      return "#{from.strftime('%-d')} – #{to.strftime('%-d %B %Y')}" if from.month == to.month

      "#{from.strftime('%-d %b')} – #{to.strftime('%-d %b %Y')}"
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      Date.current
    end

    def locale = params[:locale].presence || Nibble.config.default_locale.code
  end
end
