module Nibble
  module Cp
    class JobsDashboard
      QUEUES = %w[events deliveries media search maintenance].freeze
      FAILED_LIMIT = 50
      BACKTRACE_LINES = 25

      def self.available?
        defined?(SolidQueue::Job) && SolidQueue::Job.connection.table_exists?(SolidQueue::Job.table_name)
      rescue ActiveRecord::ActiveRecordError
        false
      end

      def props
        { available: true, queues:, in_progress:, scheduled:, failed:, recurring: }
      end

      private

      def queues
        ready = SolidQueue::ReadyExecution.group(:queue_name).count
        oldest = SolidQueue::ReadyExecution.group(:queue_name).minimum(:created_at)
        (QUEUES | ready.keys.sort).map do |name|
          { name:, ready: ready.fetch(name, 0), oldest_at: oldest[name]&.utc&.iso8601 }
        end
      end

      def in_progress
        SolidQueue::ClaimedExecution.includes(:job, :process).order(:created_at).map do |execution|
          { id: execution.job_id, job: execution.job.class_name, queue: execution.job.queue_name,
            started_at: execution.created_at.utc.iso8601, process: execution.process&.then { |process| "#{process.hostname} ##{process.pid}" } }
        end
      end

      def scheduled
        upcoming = SolidQueue::ScheduledExecution.includes(:job).order(:scheduled_at).limit(5).map do |execution|
          { id: execution.job_id, job: execution.job.class_name, queue: execution.job.queue_name, at: execution.scheduled_at.utc.iso8601 }
        end
        { count: SolidQueue::ScheduledExecution.count, upcoming: }
      end

      def failed
        SolidQueue::FailedExecution.includes(:job).order(created_at: :desc).limit(FAILED_LIMIT).map do |execution|
          { id: execution.id, job_id: execution.job_id, job: execution.job.class_name, queue: execution.job.queue_name,
            exception: execution.exception_class, message: execution.message.to_s.truncate(500),
            backtrace: Array(execution.backtrace).first(BACKTRACE_LINES), failed_at: execution.created_at.utc.iso8601 }
        end
      end

      def recurring
        last_runs = SolidQueue::RecurringExecution.group(:task_key).maximum(:run_at)
        SolidQueue::RecurringTask.order(:key).map do |task|
          { key: task.key, schedule: task.schedule, job: task.class_name || task.command, queue: task.queue_name,
            last_run_at: last_runs[task.key]&.utc&.iso8601 }
        end
      end
    end
  end
end
