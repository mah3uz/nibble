module Nibble
  module Tasks
    class Runner
      Outcome = Data.define(:status, :message, :details)

      def initialize(task, run)
        @task = task
        @run = run
      end

      def call
        case @task.action
        when "fetch" then fetch
        when "request" then request
        when "handler" then handle
        else outcome("failed", "the task has no fetch, request or handler")
        end
      rescue Error => error
        outcome("failed", error.message)
      rescue StandardError => error
        Rails.error.report(error, handled: true, context: { task: @task.handle })
        outcome("failed", "#{error.class.name}: #{error.message}")
      end

      private

      def call_out(spec, default_method)
        template = Outbound::Template.new
        options = { purpose: "task:#{@task.handle}", owner: @run, headers: template.render(spec["headers"].to_h) }
        method = spec["method"] || default_method
        response = if spec["use"].present?
          connection = Outbound::Connection.find(spec["use"]) or raise Error, "the API connection '#{spec['use']}' isn't in the schema"
          connection.request(method, spec["path"].to_s, template:, body: spec["body"], **options)
        else
          Outbound.request(method, template.render(spec["url"]), body: template.render(spec["body"]), secrets: template.secrets_used, **options)
        end
        raise Error, "the API answered HTTP #{response.status}" unless response.ok?

        response
      end

      def fetch
        response = call_out(@task.fetch, "get")
        data = response.json
        raise Error, "the response isn't JSON" if data.nil?

        into = @task.fetch["into"].to_h
        into.key?("collection") ? Import.new(@task, into, data).call : into_global(into, data)
      end

      def into_global(into, data)
        locale = into["locale"] || Nibble.config.default_locale.code
        record = Records::GlobalSet.find_or_initialize_by(handle: into["global"], locale:)
        values = Mapping.values(into["map"], "response" => data)
        missing = into["map"].to_h.keys - values.keys
        details = { "changed" => [], "missing" => missing }
        return outcome("succeeded", summary("nothing changed", missing), details) if values.empty? || (record.persisted? && Tasks.unchanged?(record, values))

        result = Lifecycle.call(record, :save, values, actor: Principal.system)
        raise Error, Tasks.describe(result.errors) unless result.ok?

        outcome("succeeded", summary("saved #{values.keys.join(', ')}", missing), details.merge("changed" => values.keys))
      end

      def request
        response = call_out(@task.request, "post")
        outcome("succeeded", "HTTP #{response.status}", { "status" => response.status })
      end

      def handle
        handler = Tasks.handlers[@task.handler] or raise Error, "the handler '#{@task.handler}' isn't registered"
        result = handler.call(Context.new(@task, @run))
        outcome("succeeded", nil, result.is_a?(Hash) ? result.deep_stringify_keys : {})
      end

      def summary(message, missing) = missing.empty? ? message : "#{message}; not in the response: #{missing.join(', ')}"

      def outcome(status, message, details = {}) = Outcome.new(status:, message:, details:)
    end
  end
end
