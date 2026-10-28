require "fugit"

module Nibble
  module Tasks
    ACTIONS = %w[fetch request handler].freeze
    # A run still unfinished after this long was lost with its worker: one run makes a single outbound call, bounded
    # by its timeout, and its saves, so nothing legitimate takes near an hour.
    STALE_AFTER = 1.hour
    RETENTION = 30.days

    Task = Data.define(:item) do
      def handle = item.handle
      def title = item["title"]
      def description = item["description"]
      def schedule = item["schedule"]
      def action = ACTIONS.find { |key| item.data.key?(key) }
      def fetch = item["fetch"].to_h
      def request = item["request"].to_h
      def handler = item["handler"]
      def cron = Tasks.cron(schedule)
      def next_run_at(now = Time.current) = cron.next_time(now).to_t.in_time_zone
    end

    Summary = Data.define(:task, :paused, :running, :failing_since, :next_run_at, :last_run)

    mattr_accessor :handlers, default: {}

    class << self
      def register_handler(name, handler) = handlers[name.to_s] = handler

      def all(schema: Nibble.schema) = schema.tasks.map { |item| Task.new(item:) }
      def find(handle, schema: Nibble.schema) = (item = schema.find(:tasks, handle.to_s)) && Task.new(item:)
      def find!(handle) = find(handle) || raise(Error, "no task '#{handle}' in the schema")

      # Parsed as Solid Queue parses recurring.yml, in the site's time zone unless the schedule names its own.
      def cron(schedule)
        parsed = begin
          Fugit.parse(schedule.to_s, multi: :fail)
        rescue ArgumentError
          nil
        end
        raise Error, "schedule '#{schedule}' isn't a schedule Nibble can read, such as `every 2 hours`, `at 5am every day` or a cron line" unless parsed.instance_of?(Fugit::Cron)

        parsed.zone ? parsed : Fugit::Cron.parse("#{parsed.to_cron_s} #{Time.zone.tzinfo.name}")
      end

      def overview(now: Time.current)
        states = Records::ScheduledTask.all.index_by(&:handle)
        all.map do |task|
          state = states[task.handle]
          last_run = Records::ScheduledTaskRun.where(handle: task.handle).recent.first
          next_run_at = begin
            task.next_run_at(now) unless state&.paused
          rescue Error
            nil
          end
          Summary.new(task:, paused: state&.paused || false, running: running?(state, now), failing_since: state&.failing_since,
                      next_run_at:, last_run:)
        end
      end

      def runs(handle, limit: 20) = Records::ScheduledTaskRun.where(handle: handle.to_s).recent.limit(limit).to_a

      def run_now(handle, now: Time.current)
        task = find!(handle)
        state_for(task.handle, now)
        start(task.handle, now, manual: true, now:)
      end

      def pause(handle, now: Time.current) = state_for(find!(handle).handle, now).tap { |state| state.update!(paused: true) }

      # Slots that passed while it was paused are not made up.
      def resume(handle, now: Time.current) = state_for(find!(handle).handle, now).tap { |state| state.update!(paused: false, active_since: now) }

      def tick(now: Time.current)
        Records::ScheduledTaskRun.where(created_at: ...now - RETENTION).find_each(&:destroy!)
        all.each do |task|
          enqueue_due(task, now)
        rescue Error => error
          Rails.logger.warn("[nibble] task #{task.handle}: #{error.message}")
        end
      end

      def perform(run, now: Time.current)
        started = Records::ScheduledTaskRun.where(id: run.id, status: "queued").update_all(status: "running", started_at: now, updated_at: now)
        return run.reload unless started == 1

        run.reload
        task = find(run.handle)
        outcome = task ? Runner.new(task, run).call : Runner::Outcome.new(status: "failed", message: "the task isn't in the schema any more", details: {})
        finish(run, task, outcome)
        run.reload
      end

      def unchanged?(record, attrs)
        fields = record.blueprint_fields
        stored = fields.add_values(record.values).values
        incoming = fields.add_values(record.values.merge(attrs)).process.values
        attrs.keys.all? { |handle| JSON.parse(incoming[handle].to_json) == JSON.parse(stored[handle].to_json) }
      end

      def describe(errors) = errors.map { |key, messages| "#{key}: #{Array(messages).join(', ')}" }.join("; ")

      private

      def state_for(handle, now)
        Records::ScheduledTask.find_by(handle:) || Records::ScheduledTask.create_or_find_by!(handle:) { |state| state.active_since = now }
      end

      def enqueue_due(task, now)
        state = state_for(task.handle, now)
        return if state.paused

        slot = task.cron.previous_time(now + 1.second).to_t.in_time_zone
        return if slot < state.active_since || Records::ScheduledTaskRun.exists?(handle: task.handle, scheduled_for: slot)

        start(task.handle, slot, manual: false, now:)
      end

      def start(handle, scheduled_for, manual:, now:)
        run = begin
          Records::ScheduledTaskRun.create!(handle:, scheduled_for:, manual:, status: "queued")
        rescue ActiveRecord::RecordNotUnique
          return nil
        end
        if claim(run, now)
          Jobs::RunTask.perform_later(run.id)
        else
          run.update!(status: "skipped", finished_at: now, message: "the previous run was still going")
        end
        run
      end

      # One run per task at a time, settled by a compare-and-set on the task's row, so it holds across workers.
      def claim(run, now)
        state = Records::ScheduledTask.find_by!(handle: run.handle)
        previous = state.current_run_id
        return false if previous && state.claimed_at > now - STALE_AFTER

        taken = Records::ScheduledTask.where(id: state.id, current_run_id: previous)
          .update_all(current_run_id: run.id, claimed_at: now, updated_at: now) == 1
        if taken && previous
          Records::ScheduledTaskRun.where(id: previous, finished_at: nil)
            .update_all(status: "failed", finished_at: now, message: "stopped without finishing", updated_at: now)
        end
        taken
      end

      def running?(state, now) = state&.current_run_id.present? && state.claimed_at > now - STALE_AFTER

      def finish(run, task, outcome, now: Time.current)
        won = Records::ScheduledTaskRun.where(id: run.id, finished_at: nil).update_all(status: outcome.status, finished_at: now, updated_at: now) == 1
        run.update_columns(message: outcome.message&.truncate(250), details: outcome.details) if won
        Records::ScheduledTask.where(handle: run.handle, current_run_id: run.id).update_all(current_run_id: nil, claimed_at: nil, updated_at: now)
        return unless won

        if outcome.status == "failed"
          alert(task, run, outcome) if Records::ScheduledTask.where(handle: run.handle, failing_since: nil).update_all(failing_since: now, updated_at: now) == 1
        else
          Records::ScheduledTask.where(handle: run.handle).where.not(failing_since: nil).update_all(failing_since: nil, updated_at: now)
        end
      end

      def alert(task, run, outcome)
        Nibble::User.administrators.find_each do |user|
          Records::Notification.notify(user.id, "task.failed", title: task&.title || run.handle, task: run.handle, message: outcome.message)
        end
      end
    end
  end
end
