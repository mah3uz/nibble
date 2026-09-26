module Nibble
  module Cp
    module WidgetStats
      DAYS = 30
      EDITS = %w[record.created record.saved].freeze
      MIX = { "published" => %w[published], "scheduled" => %w[scheduled], "in_review" => %w[in_review approved],
              "draft" => %w[draft], "unpublished" => %w[unpublished] }.freeze

      module_function

      def overview(user, entries:, forms:)
        [
          tile("published", "Published", entries.where(status: "published").where(published_at: since..Time.current).pluck(:published_at),
               listing_url(entries, "published")),
          tile("edits", "Edits", events(EDITS).pluck(:created_at), "/cp/utilities/audit"),
          (tile("submissions", "Form submissions", Records::FormSubmission.kept.where(form: forms, created_at: since..).pluck(:created_at),
                "/cp/forms") if forms.any?),
          (tile("uploads", "Uploads", Records::Asset.kept.where(created_at: since..).pluck(:created_at), "/cp/media") if
            Access.can?(user, "assets.view"))
        ].compact
      end

      def activity_chart
        {
          "start" => start_date.iso8601,
          "series" => [
            { "key" => "edits", "label" => "Edits", "values" => daily(events(EDITS).where(created_at: start_date.beginning_of_day..).pluck(:created_at)) },
            { "key" => "published", "label" => "Published",
              "values" => daily(events(%w[record.published]).where(created_at: start_date.beginning_of_day..).pluck(:created_at)) }
          ]
        }
      end

      def content_mix(collections)
        counts = Records::Entry.kept.where(collection: collections.map(&:handle)).group(:collection, :status).count
        collections.map do |collection|
          mix = MIX.transform_values { |statuses| statuses.sum { |status| counts.fetch([ collection.handle, status ], 0) } }
          # A folder's pages are live the moment they are deployed, and have no rows to count.
          mix["published"] += Files.index.of(collection.handle).size if collection["files"].present?
          { "handle" => collection.handle, "title" => collection["title"] || collection.handle.humanize,
            "url" => "/cp/collections/#{collection.handle}", "counts" => mix, "total" => mix.values.sum }
        end
      end

      def tile(key, label, times, url)
        series = daily(times)
        { "key" => key, "label" => label, "url" => url, "total" => series.sum, "series" => series }
      end

      def daily(times)
        counts = times.compact.map { |time| time.in_time_zone.to_date }.tally
        today = Time.zone.today
        (DAYS - 1).downto(0).map { |ago| counts.fetch(today - ago, 0) }
      end

      def events(actions) = Records::AuditEntry.where(action: actions, created_at: since..)
      def since = start_date.beginning_of_day
      def start_date = Time.zone.today - (DAYS - 1)

      def listing_url(entries, status)
        collection = entries.distinct.pick(:collection) or return "/cp"

        "/cp/collections/#{collection}?status=#{status}"
      end
    end
  end
end
