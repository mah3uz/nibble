module Nibble
  module Cp
    module Widgets
      LIMIT = 5

      AVAILABLE = {
        "overview" => "At a glance",
        "activity_chart" => "Editing activity",
        "content_mix" => "Content by collection",
        "recent_entries" => "Recently edited",
        "drafts" => "Unpublished changes",
        "awaiting_review" => "Awaiting your review",
        "scheduled" => "Scheduled",
        "content_health" => "Needs attention",
        "form_submissions" => "Form submissions",
        "missing_pages" => "Top missing pages",
        "site_health" => "Site health",
        "failures" => "Failed deliveries",
        "comments" => "Recent comments",
        "uploads" => "Recent uploads",
        "activity" => "Activity",
        "quick_links" => "Quick links"
      }.freeze

      DEFAULT = [
        { "type" => "overview", "width" => 100 },
        { "type" => "activity_chart", "width" => 66 },
        { "type" => "content_mix", "width" => 33 },
        { "type" => "recent_entries", "width" => 50 },
        { "type" => "drafts", "width" => 50 },
        { "type" => "awaiting_review", "width" => 50 },
        { "type" => "scheduled", "width" => 50 },
        { "type" => "activity", "width" => 66 },
        { "type" => "quick_links", "width" => 33 },
        { "type" => "form_submissions", "width" => 50 },
        { "type" => "site_health", "width" => 50 }
      ].freeze

      class << self
        def layout(user)
          (UserPreferences.get(user, "dashboard.widgets").presence || DEFAULT).select { |widget| allowed?(user, widget["type"]) }
        end

        def available(user)
          AVAILABLE.filter_map { |type, label| { "type" => type, "label" => label } if allowed?(user, type) }
        end

        def data(user) = layout(user).to_h { |widget| [ widget["type"], data_for(user, widget["type"]) ] }

        private

        def allowed?(user, type)
          case type
          when "awaiting_review" then approvable(user).any?
          when "form_submissions" then forms(user).any?
          when "missing_pages" then Access.can?(user, "redirects.manage")
          when "site_health" then Access.can?(user, "utilities.view")
          when "failures" then Access.can?(user, "webhooks.manage") || Access.can?(user, "utilities.view")
          when "uploads" then Access.can?(user, "assets.view")
          else AVAILABLE.key?(type)
          end
        end

        def data_for(user, type)
          case type
          when "overview" then { "tiles" => WidgetStats.overview(user, entries: visible(user), forms: forms(user)) }
          when "activity_chart" then WidgetStats.activity_chart
          when "content_mix" then { "collections" => WidgetStats.content_mix(collections(user)) }
          when "recent_entries" then { "items" => entries(visible(user).order(updated_at: :desc)), "create_url" => create_url(user) }
          when "drafts" then { "items" => drafts(user) }
          when "awaiting_review" then { "items" => awaiting_review(user) }
          when "scheduled" then { "items" => entries(visible(user).where(status: "scheduled").order(:published_at)) }
          when "content_health" then { "items" => health(user) }
          when "form_submissions" then submissions(user)
          when "missing_pages" then { "items" => missing_pages }
          when "site_health" then site_health
          when "failures" then { "items" => failures(user) }
          when "comments" then { "items" => comments(user) }
          when "uploads" then { "items" => uploads }
          when "activity" then { "items" => activity(user) }
          when "quick_links" then { "links" => quick_links(user) }
          end
        end

        def collections(user)
          Nibble.schema.collections.select { |item| Access.can?(user, "entries.#{item.handle}.view") }
        end

        def visible(user) = Records::Entry.kept.where(collection: collections(user).map(&:handle))

        def entries(scope)
          scope.limit(LIMIT).map { |entry| item(entry) }
        end

        def item(entry, extra = {})
          {
            "id" => entry.id, "type" => "entry", "title" => entry.title.to_s.presence || "Untitled", "path" => entry.uri,
            "status" => entry.status, "live" => entry.live?, "updated_at" => entry.updated_at.utc.iso8601,
            "published_at" => entry.published_at&.utc&.iso8601,
            "edit_url" => "/admin/collections/#{entry.collection}/entries/#{entry.id}/edit"
          }.merge(extra)
        end

        def drafts(user)
          drafts = Records::Draft.where(record_type: "entry").includes(:author).order(updated_at: :desc).limit(LIMIT)
          entries = visible(user).where(id: drafts.map(&:record_id)).index_by(&:id)
          drafts.filter_map do |draft|
            entry = entries[draft.record_id] or next

            item(entry, "user" => draft.author&.name, "updated_at" => draft.updated_at.utc.iso8601)
          end
        end

        def health(user)
          [
            { "label" => "Awaiting review", "count" => visible(user).where(status: %w[in_review approved]).count, "url" => listing_url(user, "in_review") },
            { "label" => "Drafts", "count" => visible(user).where(status: "draft").count, "url" => listing_url(user, "draft") },
            { "label" => "In the trash", "count" => Records::Entry.where.not(deleted_at: nil).count, "url" => "/admin/trash" }
          ]
        end

        VERBS = {
          "record.created" => "created", "record.saved" => "edited", "record.published" => "published",
          "record.unpublished" => "unpublished", "record.scheduled" => "scheduled", "record.trashed" => "moved",
          "record.restored" => "restored", "record.deleted" => "deleted", "record.reverted" => "reverted",
          "record.moved" => "moved", "record.replaced" => "replaced the file of"
        }.freeze

        def activity(user)
          entries = Records::AuditEntry.where(Records::AuditEntry.arel_table[:action].matches("record.%")).order(created_at: :desc).limit(LIMIT).to_a
          authors = ::User.where(id: entries.filter_map(&:actor_id)).index_by(&:id)
          entries.map do |entry|
            title, url = subject_of(entry)
            {
              "item_type" => entry.subject_type, "event" => entry.action.to_s.split(".").last,
              "verb" => VERBS.fetch(entry.action) { entry.action.to_s.split(".").last.humanize(capitalize: false) },
              "created_at" => entry.created_at.utc.iso8601, "author" => authors[entry.actor_id]&.name,
              "title" => title, "url" => url, "after" => entry.action == "record.trashed" ? "to the trash" : nil
            }
          end
        end

        def subject_of(entry)
          case entry.subject_type
          when "entry"
            record = Records::Entry.find_by(id: entry.subject_id) or return [ "a deleted entry", nil ]
            [ record.title, "/admin/collections/#{record.collection}/entries/#{record.id}/edit" ]
          when "term"
            record = Records::Term.find_by(id: entry.subject_id) or return [ "a deleted term", nil ]
            [ record.title, "/admin/taxonomies/#{record.taxonomy}/terms/#{record.id}/edit" ]
          when "global"
            record = Records::GlobalSet.find_by(id: entry.subject_id) or return [ "a global set", nil ]
            [ "the #{record.item&.[]('title') || record.handle.humanize} globals", "/admin/globals/#{record.handle}/edit" ]
          when "navigation"
            record = Records::NavigationTree.find_by(id: entry.subject_id) or return [ "a menu", nil ]
            [ "the #{Nibble.schema.find(:navigation, record.handle)&.[]('title') || record.handle.humanize} menu",
              "/admin/navigation/#{record.handle}/edit" ]
          when "asset"
            record = Records::Asset.find_by(id: entry.subject_id) or return [ "an asset", nil ]
            [ record.title.presence || record.filename, "/admin/media" ]
          else
            [ entry.subject_type.to_s.humanize(capitalize: false), nil ]
          end
        end

        def quick_links(user)
          links = collections(user).filter_map do |collection|
            next unless Access.can?(user, "entries.#{collection.handle}.create")

            noun = collection["title"].to_s.singularize.downcase
            { "label" => "New #{noun}", "url" => "/admin/collections/#{collection.handle}/entries/new",
              "icon" => collection["icon"] || "collections", "description" => "Start a #{noun} from its blueprint." }
          end
          if Access.can?(user, "assets.upload")
            links << { "label" => "Upload assets", "url" => "/admin/media", "icon" => "assets",
                       "description" => "Add images and files to the library." }
          end
          if Access.can?(user, "utilities.view")
            links << { "label" => "Utilities", "url" => "/admin/utilities", "icon" => "utilities",
                       "description" => "Cache, search, jobs, health and backups." }
          end
          links
        end

        def approvable(user) = collections(user).select { |item| Access.can?(user, "workflow.approve.#{item.handle}") }

        def awaiting_review(user)
          scope = Records::Entry.kept.where(collection: approvable(user).map(&:handle), status: "in_review").order(:updated_at).limit(LIMIT).to_a
          since = Records::WorkflowTransition.where(record_type: "entry", record_id: scope.map(&:id), to: "in_review")
                                             .group(:record_id).maximum(:created_at)
          authors = ::User.where(id: scope.filter_map(&:updated_by_id)).index_by(&:id)
          scope.map do |entry|
            item(entry, "user" => authors[entry.updated_by_id]&.name, "since" => (since[entry.id] || entry.updated_at).utc.iso8601)
          end
        end

        def forms(user) = Forms.all.select { |form| Access.can?(user, "forms.#{form.handle}.view") }.map(&:handle)

        def submissions(user)
          titles = Forms.all.to_h { |form| [ form.handle, form.title || form.handle.humanize ] }
          scope = Records::FormSubmission.kept.where(form: forms(user))
          items = scope.order(created_at: :desc).limit(LIMIT).map do |submission|
            { "id" => submission.id, "form" => titles[submission.form], "unread" => !submission.read?,
              "summary" => submission.data.values.find { |value| value.is_a?(String) && value.present? }.to_s.truncate(80),
              "created_at" => submission.created_at.utc.iso8601, "url" => "/admin/forms/#{submission.form}/submissions/#{submission.id}" }
          end
          { "items" => items, "unread" => scope.unread.count }
        end

        def missing_pages
          Records::NotFound.order(hits: :desc, last_seen_at: :desc).limit(LIMIT).map do |row|
            { "path" => row.path, "hits" => row.hits, "last_seen_at" => row.last_seen_at.utc.iso8601,
              "redirect_url" => "/admin/redirects?#{{ from: row.path }.to_query}" }
          end
        end

        def site_health
          checks = Health.run
          { "status" => Health.status(checks), "url" => "/admin/utilities/health",
            "checks" => checks.map { |check| { "name" => check.name, "status" => check.status, "message" => check.message, "ms" => check.ms } } }
        end

        def failures(user)
          items = []
          if Access.can?(user, "webhooks.manage")
            Records::WebhookDelivery.where(status: "failed").includes(:webhook).order(updated_at: :desc).limit(LIMIT).each do |delivery|
              items << { "title" => delivery.webhook&.name.to_s, "detail" => delivery.error.presence || "HTTP #{delivery.response_status}",
                         "kind" => "Webhook", "at" => delivery.updated_at.utc.iso8601, "url" => "/admin/webhooks/#{delivery.webhook_id}/edit" }
            end
          end
          if Access.can?(user, "utilities.view") && JobsDashboard.available?
            SolidQueue::FailedExecution.includes(:job).order(created_at: :desc).limit(LIMIT).each do |failure|
              items << { "title" => failure.job.class_name, "detail" => failure.message.to_s.lines.first.to_s.strip,
                         "kind" => "Job", "at" => failure.created_at.utc.iso8601, "url" => "/admin/utilities/jobs" }
            end
          end
          items.sort_by { |row| row["at"] }.reverse.first(LIMIT)
        end

        def comments(user)
          visible_ids = visible(user).select(:id)
          rows = Records::Comment.where(subject_type: Records::Entry.name, subject_id: visible_ids).order(created_at: :desc).limit(LIMIT).to_a
          entries = Records::Entry.where(id: rows.map(&:subject_id)).index_by(&:id)
          authors = ::User.where(id: rows.map(&:author_id)).index_by(&:id)
          rows.map do |comment|
            entry = entries[comment.subject_id]
            { "id" => comment.id, "author" => authors[comment.author_id]&.name, "body" => comment.body.truncate(140),
              "title" => entry.title.to_s.presence || "Untitled", "resolved" => comment.resolved_at.present?,
              "created_at" => comment.created_at.utc.iso8601, "url" => "/admin/collections/#{entry.collection}/entries/#{entry.id}/edit" }
          end
        end

        def uploads
          Records::Asset.kept.order(created_at: :desc).limit(8).map do |asset|
            { "id" => asset.id, "title" => asset.display_title, "kind" => asset.kind, "extension" => asset.extension,
              "thumbnail" => asset.thumbnail_url, "created_at" => asset.created_at.utc.iso8601,
              "url" => "/admin/media?#{{ folder: asset.folder.presence, asset: asset.id }.compact.to_query}" }
          end
        end

        def create_url(user)
          collection = collections(user).find { |item| Access.can?(user, "entries.#{item.handle}.create") } or return nil

          "/admin/collections/#{collection.handle}/entries/new"
        end

        def listing_url(user, status)
          collection = collections(user).first or return "/admin"

          "/admin/collections/#{collection.handle}?status=#{status}"
        end
      end
    end
  end
end
