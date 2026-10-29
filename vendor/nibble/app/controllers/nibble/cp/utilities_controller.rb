module Nibble
  module Cp
    class UtilitiesController < BaseController
      before_action { authorize!("utilities.view") }
      before_action :require_elevated_page, only: :content

      AUDIT_PAGE = 25

      def show
        render inertia: "cp/utilities/Index", props: { utilities: Nibble::Cp::Utilities::LIST.map { |utility| utility.merge(url: Nibble::Cp::Utilities.url(utility)) } }
      end

      def cache
        render inertia: "cp/utilities/Cache", props: { store: Nibble::PageCache.store.class.name.demodulize.underscore.humanize }
      end

      def search
        render inertia: "cp/utilities/Search", props: { search: search_stats }
      end

      def schema
        render inertia: "cp/utilities/Schema", props: {
          schema: schema_overview,
          checks: Nibble::Check.run.findings.map { |problem| { source: problem.source, message: problem.message, level: problem.level } }
        }
      end

      def backups
        render inertia: "cp/utilities/Backups", props: { backups: backup_info }
      end

      def audit
        before = Integer(params[:before].to_s, exception: false)
        scope = Nibble::Records::AuditEntry.order(id: :desc)
        scope = scope.where(id: ...before) if before
        rows = scope.limit(AUDIT_PAGE + 1).to_a
        older = rows.size > AUDIT_PAGE ? rows[AUDIT_PAGE - 1].id : nil
        page = { page_name: "before", previous_page: nil, next_page: older, current_page: before }
        render inertia: "cp/utilities/Audit", props: { audit: InertiaRails.scroll(page) { audit_rows(rows.first(AUDIT_PAGE)) } }
      end

      REPORT_ERRORS = 15

      def content
        render inertia: "cp/utilities/Content", props: {
          can_export: Nibble::Access.can?(Nibble::Current.user, "content.export"),
          can_import: Nibble::Access.can?(Nibble::Current.user, "content.import"),
          report: flash[:import_report]
        }
      end

      def export_content
        authorize!("content.export")
        Dir.mktmpdir("nibble-export") do |dir|
          Nibble::Packages::Exporter.new(dir).call
          send_data Nibble::Packages::Archive.write(dir), type: "application/zip",
            filename: "content-#{URI.parse(Nibble.config.url.to_s).host}-#{Date.current.iso8601}.zip"
        end
      end

      def import_content
        authorize!("content.import")
        confirm = params[:confirm] == "1"
        return redirect_to(content_cp_utilities_path) if confirm && !elevated?

        Dir.mktmpdir("nibble-import") do |dir|
          Nibble::Packages::Archive.extract(params.require(:package).tempfile, into: dir)
          importer = Nibble::Packages::Importer.new(dir, mode: params[:mode].presence || "create", notify: params[:webhooks] == "1")
          report = confirm ? importer.call : importer.preview
          Nibble::Events.dispatch_pending if confirm && report.ok?
          flash[:import_report] = report_props(report, confirm:)
        end
        redirect_to content_cp_utilities_path
      rescue Nibble::Error => e
        redirect_to content_cp_utilities_path, alert: e.message
      end

      def health
        checks = Nibble::Health.run
        render inertia: "cp/utilities/Health", props: { status: Nibble::Health.status(checks), checks: checks.map(&:to_h),
                                                             checked_at: Time.current.utc.iso8601, system: system_info }
      end

      def jobs
        props = Nibble::Cp::JobsDashboard.available? ? Nibble::Cp::JobsDashboard.new.props : { available: false }
        render inertia: "cp/utilities/Jobs", props: { jobs: props }
      end

      def retry_job
        failed_execution.retry
        redirect_to jobs_cp_utilities_path, notice: "Job queued to run again."
      end

      def discard_job
        failed_execution.discard
        redirect_to jobs_cp_utilities_path, notice: "Job discarded."
      end

      TASK_RUNS = 100

      def tasks
        render inertia: "cp/utilities/Tasks", props: {
          tasks: Nibble::Tasks.overview.map { |summary| task_props(summary) },
          scheduler: Nibble::Cp::JobsDashboard.available?,
          time_zone: Time.zone.tzinfo.name
        }
      end

      def task_runs
        task = find_task
        runs = Nibble::Tasks.runs(task.handle, limit: TASK_RUNS).select { |run| run.created_at >= Nibble::Tasks::RETENTION.ago }
        render json: { runs: runs.map { |run| run_props(run) }, limit: TASK_RUNS }
      end

      def run_task
        task = find_task
        run = Nibble::Tasks.run_now(task.handle)
        if run.nil?
          redirect_to tasks_cp_utilities_path, notice: "#{task.title} was started a moment ago."
        elsif run.status == "skipped"
          redirect_to tasks_cp_utilities_path, alert: "#{task.title} didn't start: its previous run is still going."
        else
          redirect_to tasks_cp_utilities_path, notice: "#{task.title} is queued to run."
        end
      end

      def pause_task
        task = find_task
        Nibble::Tasks.pause(task.handle)
        redirect_to tasks_cp_utilities_path, notice: "#{task.title} is paused."
      end

      def resume_task
        task = find_task
        Nibble::Tasks.resume(task.handle)
        redirect_to tasks_cp_utilities_path, notice: "#{task.title} is resumed, from its next slot."
      end

      def clear_cache
        Nibble::PageCache.store.clear
        redirect_to cache_cp_utilities_path, notice: "Page cache cleared."
      end

      def purge_cache
        tags = params[:tags].to_s.split(/[\s,]+/).compact_blank
        return redirect_to cache_cp_utilities_path, alert: "Name at least one cache tag." if tags.empty?

        Nibble::PageCache.purge(tags)
        redirect_to cache_cp_utilities_path, notice: "Cleared pages tagged #{tags.to_sentence}."
      end

      def rebuild_search
        authorize!("search.rebuild")
        Nibble::Search.rebuild
        redirect_to search_cp_utilities_path, notice: "Search indexes rebuilt."
      end

      private

      def search_stats
        indexed = Nibble::Search::TABLES.values.sum { |table| Nibble::Records::Entry.connection.select_value("SELECT COUNT(*) FROM #{table}").to_i }
        collections = Nibble::Search.indexes.values.flat_map { |definition| Array(definition["collections"]) }
        indexes = Nibble::Search.indexes.map do |handle, definition|
          { handle:, collections: Array(definition["collections"]), taxonomies: Array(definition["taxonomies"]),
            fields: Array(definition["fields"]).map { |field| field.is_a?(Hash) ? field["handle"] || field.keys.first : field }.compact }
        end
        { indexes:, indexed:, total: Nibble::Records::Entry.live.where(collection: collections).count,
          can_rebuild: Nibble::Access.can?(Nibble::Current.user, "search.rebuild") }
      end

      def backup_info
        latest = Dir.glob(DatabaseSnapshot.local_dir.join("*.sqlite3.gz")).max_by { |path| File.mtime(path) }
        {
          configured: ENV["DB_SNAPSHOT_BUCKET"].present?,
          latest: latest && { name: File.basename(latest), created_at: File.mtime(latest).utc.iso8601,
                              size: ActiveSupport::NumberHelper.number_to_human_size(File.size(latest)) }
        }
      end

      def audit_rows(entries)
        actors = Nibble::User.where(id: entries.filter_map(&:actor_id)).index_by(&:id)
        entries.map do |entry|
          { id: entry.id, action: entry.action, at: entry.created_at.utc.iso8601, ip: entry.ip,
            actor: actors[entry.actor_id]&.name, subject: [ entry.subject_type, entry.subject_id ].compact.join(" "),
            changed: entry.changeset.keys.sort }
        end
      end

      def report_props(report, confirm:)
        { imported: confirm && report.ok?, ok: report.ok?, mode: params[:mode].presence || "create",
          created: report.created.size, updated: report.updated.size, skipped: report.skipped.size,
          errors: report.errors.first(REPORT_ERRORS), more_errors: [ report.errors.size - REPORT_ERRORS, 0 ].max }
      end

      def find_task = Nibble::Tasks.find(params[:handle]) || raise(ActiveRecord::RecordNotFound)

      def task_props(summary)
        task = summary.task
        { handle: task.handle, title: task.title, description: task.description, schedule: task.schedule,
          paused: summary.paused, running: summary.running, failing_since: summary.failing_since&.utc&.iso8601,
          next_run_at: summary.next_run_at&.utc&.iso8601, last_run: summary.last_run && run_props(summary.last_run) }
      end

      def run_props(run)
        { id: run.id, status: run.status, manual: run.manual, scheduled_for: run.scheduled_for.utc.iso8601,
          started_at: run.started_at&.utc&.iso8601, finished_at: run.finished_at&.utc&.iso8601,
          message: run.message, details: run.details }
      end

      def failed_execution
        raise ActiveRecord::RecordNotFound unless Nibble::Cp::JobsDashboard.available?

        SolidQueue::FailedExecution.find(params[:id])
      end

      def schema_overview
        schema = Nibble.schema
        {
          digest: schema.digest.first(12),
          theme: Nibble.config.theme,
          collections: schema.collections.map { |item| { handle: item.handle, title: item["title"] } },
          taxonomies: schema.taxonomies.map { |item| { handle: item.handle, title: item["title"] } },
          globals: schema.globals.map { |item| { handle: item.handle, title: item["title"] } },
          navigations: schema.navigations.map { |item| { handle: item.handle, title: item["title"] } }
        }
      end

      def system_info
        {
          nibble: Nibble::SCHEMA_FORMAT, rails: Rails.version, ruby: RUBY_VERSION, environment: Rails.env,
          entries: Nibble::Records::Entry.kept.count, terms: Nibble::Records::Term.kept.count,
          trashed: Nibble::Records::Entry.where.not(deleted_at: nil).count + Nibble::Records::Term.where.not(deleted_at: nil).count,
          pending_events: Nibble::Records::OutboxEvent.pending.count
        }
      end
    end
  end
end
