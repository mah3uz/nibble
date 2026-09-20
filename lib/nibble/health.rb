module Nibble
  module Health
    Check = Data.define(:name, :status, :message, :ms)

    QUEUE_LAG = 5.minutes
    SCHEDULE_TASK = "run_publishing_schedule".freeze
    SSR_TIMEOUT = 2

    module_function

    def run = [ timed("database") { database }, timed("queue") { queue }, timed("storage") { storage }, timed("ssr") { ssr } ]

    def status(checks)
      return "down" if checks.any? { |check| check.status == "fail" }

      checks.any? { |check| check.status == "warn" } ? "degraded" : "ok"
    end

    def timed(name)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status, message = begin
        yield
      rescue StandardError => e
        [ "fail", "#{e.class}: #{e.message.to_s.lines.first&.strip}" ]
      end
      Check.new(name:, status:, message:, ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1))
    end

    def database
      ActiveRecord::Base.connection.select_value("SELECT 1")
      pending = ActiveRecord::Base.connection_pool.migration_context.open.pending_migrations.size
      return [ "fail", "#{pending} database #{'migration'.pluralize(pending)} haven't run" ] if pending.positive?

      [ "ok", "Reachable, schema up to date" ]
    end

    def queue
      return [ "skip", "Solid Queue isn't running in this environment" ] unless Cp::JobsDashboard.available?

      workers = SolidQueue::Process.where(kind: "Worker").where(last_heartbeat_at: SolidQueue.process_alive_threshold.ago..).count
      return [ "fail", "No worker has checked in for #{SolidQueue.process_alive_threshold.inspect}" ] if workers.zero?

      last_schedule = SolidQueue::RecurringExecution.where(task_key: SCHEDULE_TASK).maximum(:run_at)
      if SolidQueue::RecurringTask.exists?(key: SCHEDULE_TASK) && (last_schedule.nil? || last_schedule < QUEUE_LAG.ago)
        return [ "fail", "Scheduled publishing last ran #{last_schedule ? "#{ActionController::Base.helpers.time_ago_in_words(last_schedule)} ago" : 'never'}" ]
      end

      oldest = SolidQueue::ReadyExecution.group(:queue_name).minimum(:created_at).min_by { |_, at| at }
      return [ "warn", "Work in #{oldest.first} has waited since #{oldest.last.utc.iso8601}" ] if oldest && oldest.last < QUEUE_LAG.ago

      failed = SolidQueue::FailedExecution.count
      return [ "warn", "#{failed} failed #{'job'.pluralize(failed)} waiting for a retry or discard" ] if failed.positive?

      [ "ok", "#{workers} #{'worker'.pluralize(workers)} running, nothing waiting long" ]
    end

    def storage
      service = ActiveStorage::Blob.service
      service.exist?("nibble-health-check")
      [ "ok", "#{service.class.name.demodulize.delete_suffix('Service')} storage answered" ]
    end

    def ssr
      return [ "skip", "Server rendering is off in this environment" ] unless InertiaRails.configuration.ssr_enabled

      url = URI.join(InertiaRails.configuration.ssr_url.presence || "http://localhost:13714", "/health")
      response = Net::HTTP.start(url.host, url.port, open_timeout: SSR_TIMEOUT, read_timeout: SSR_TIMEOUT) { |http| http.get(url.path) }
      return [ "ok", "The SSR server answered" ] if response.is_a?(Net::HTTPSuccess)

      [ "fail", "The SSR server answered #{response.code}" ]
    end
  end
end
