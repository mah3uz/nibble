module Nibble
  # Tools for people building on Nibble with an agent: a page's whole outcome, checks, tests, logs and docs, answered as
  # structured data. They run only in development, where the code reloads between calls.
  module Dev
    Tool = Data.define(:name, :title, :description, :input, :read_only, :handler) do
      def listing
        { "name" => name, "title" => title, "description" => description, "inputSchema" => input,
          "annotations" => { "title" => title, "readOnlyHint" => read_only, "destructiveHint" => false, "openWorldHint" => false } }
      end
    end

    class Refused < StandardError; end

    LIMIT = 60_000
    GROUPS = %w[Project Pages Logs Checks Docs].freeze

    module_function

    def tools = @tools ||= GROUPS.flat_map { |group| const_get(group).tools }.index_by(&:name)

    def allowed? = Rails.env.development? && Rails.application.config.enable_reloading

    def call(name, input, guarded: true)
      raise Refused, "the developer tools run only in development, with code reloading on" if guarded && !allowed?

      tool = tools[name.to_s] or raise Refused, "there is no tool called #{name}; tools: #{tools.keys.join(', ')}"
      Rails.application.reloader.wrap { bounded(tool.handler.call(input.to_h.deep_stringify_keys)) }
    end

    def bounded(value)
      json = value.to_json
      return value if json.length <= LIMIT

      { "truncated" => true, "size" => json.length, "preview" => json.first(LIMIT), "hint" => "Narrow the request to see the rest." }
    end

    def compact(value, depth = 0)
      case value
      when String then clip(value, 800)
      when Array
        items = value.first(10).map { |item| compact(item, depth + 1) }
        value.size > 10 ? items + [ "… #{value.size - 10} more" ] : items
      when Hash then depth > 6 ? "{…}" : value.transform_values { |item| compact(item, depth + 1) }
      else value
      end
    end

    def schema(properties = {}, required = []) = { "type" => "object", "properties" => properties, "required" => required.presence }.compact

    def relative(path) = Pathname(path).expand_path.relative_path_from(Rails.root).to_s

    def owner(path)
      full = Pathname(path).expand_path.to_s
      return "nibble" if full.start_with?(Nibble.core_root.to_s)

      full.start_with?(Rails.root.to_s) ? "site" : "outside"
    end

    def clip(text, size = 500) = text.to_s.length > size ? "#{text.to_s.first(size)}…" : text.to_s

    def run(*command, env: {}, timeout: 600)
      Open3.popen2e(env, *command, chdir: Rails.root.to_s) do |stdin, output, waiter|
        stdin.close
        reader = Thread.new { output.read }
        unless waiter.join(timeout)
          Process.kill("TERM", waiter.pid)
          return [ "#{reader.value}\n(stopped after #{timeout} seconds)", false ]
        end
        [ reader.value, waiter.value.success? ]
      end
    end
  end
end
