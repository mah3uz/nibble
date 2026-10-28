module Nibble
  module Tasks
    # What a task handler is given: the supported way for a site's Ruby to change a global or call an API connection.
    class Context
      Client = Data.define(:connection, :purpose, :owner) do
        def get(path, **options) = request(:get, path, **options)
        def post(path, body: nil, **options) = request(:post, path, body:, **options)
        def request(method, path, **options) = connection.request(method, path, purpose:, owner:, **options)
      end

      attr_reader :task

      def initialize(task, run)
        @task = task
        @run = run
      end

      def logger = Rails.logger

      def last_success_at
        Records::ScheduledTaskRun.where(handle: task.handle, status: "succeeded").where.not(id: @run.id).maximum(:started_at)
      end

      def update_global(handle, values, locale: nil)
        record = Records::GlobalSet.find_or_initialize_by(handle: handle.to_s, locale: locale || Nibble.config.default_locale.code)
        values = values.to_h.deep_stringify_keys
        return record if record.persisted? && Tasks.unchanged?(record, values)

        result = Lifecycle.call(record, :save, values, actor: Principal.system)
        raise Error, Tasks.describe(result.errors) unless result.ok?

        record
      end

      def connection(handle)
        found = Outbound::Connection.find(handle.to_s) or raise Error, "the API connection '#{handle}' isn't in the schema"
        Client.new(connection: found, purpose: "task:#{task.handle}", owner: @run)
      end
    end
  end
end
