module Nibble
  module Dev
    # The developer tools over MCP on standard input and output: one JSON-RPC message per line, no network listener.
    class McpServer
      VERSIONS = %w[2026-07-28 2025-11-25 2025-06-18 2025-03-26].freeze
      INSTRUCTIONS = <<~TEXT.freeze
        This is a Nibble site: a Rails application whose CMS lives in vendor/nibble/. Read vendor/nibble/NIBBLE-ARCHITECTURE.md
        before changing anything, and AGENTS.md for this site's own conventions.

        - vendor/nibble/ is Nibble's and an upgrade replaces it. Never edit files there. where_is says whose a file is and
          how the site changes it: its own schema layer in site/schema/, its own theme in site/themes/, eject for Control
          Plane screens, or a slot under site/cp/slots/.
        - After changing a view, a layout or its .yml sidecar, call render with a path that uses it and read the props,
          the files that answered and any error. After changing schema YAML, call check.
        - run_tests returns failures only. logs and last_error show what happened while the site ran in development:
          requests, Rails errors, server-rendering failures, failed jobs, Vite build errors and errors in the browser.
        - search_docs and read_doc read the documentation for the Nibble version installed here.
      TEXT

      def initialize(input = $stdin, output = $stdout, guarded: true)
        @input = input
        @output = output
        @guarded = guarded
      end

      def run
        @output.sync = true
        @input.each_line do |line|
          next if line.strip.empty?

          reply = respond(line)
          @output.puts(reply.to_json) if reply
        end
      end

      def respond(line)
        message = JSON.parse(line)
        return nil unless message.is_a?(Hash) && message.key?("id")

        { "jsonrpc" => "2.0", "id" => message["id"], "result" => answer(message["method"].to_s, message["params"].to_h) }
      rescue JSON::ParserError
        { "jsonrpc" => "2.0", "id" => nil, "error" => { "code" => -32700, "message" => "the line isn't JSON" } }
      rescue ArgumentError => error
        { "jsonrpc" => "2.0", "id" => message["id"], "error" => { "code" => -32602, "message" => error.message } }
      end

      private

      def answer(method, params)
        case method
        when "initialize"
          requested = params["protocolVersion"].to_s
          { "protocolVersion" => VERSIONS.include?(requested) ? requested : VERSIONS[1], "capabilities" => { "tools" => { "listChanged" => false } },
            "serverInfo" => info, "instructions" => INSTRUCTIONS }
        when "server/discover"
          { "supportedVersions" => VERSIONS, "capabilities" => { "tools" => { "listChanged" => false } }, "serverInfo" => info,
            "instructions" => INSTRUCTIONS, "resultType" => "complete" }
        when "ping" then {}
        when "tools/list" then { "tools" => Dev.tools.values.map(&:listing), "ttlMs" => 60_000, "cacheScope" => "private", "resultType" => "complete" }
        when "tools/call" then call(params)
        when "resources/list" then { "resources" => [] }
        when "prompts/list" then { "prompts" => [] }
        else raise ArgumentError, "#{method} isn't supported"
        end
      end

      def info = { "name" => "nibble-dev", "title" => "Nibble developer tools", "version" => Nibble::VERSION }

      def call(params)
        name = params["name"].to_s
        raise ArgumentError, "there is no tool called #{name}" unless Dev.tools.key?(name)

        data = Dev.call(name, params["arguments"].to_h, guarded: @guarded)
        failed = data.is_a?(Hash) && data["error"].is_a?(String)
        { "content" => [ { "type" => "text", "text" => data.to_json } ], "structuredContent" => data, "isError" => failed, "resultType" => "complete" }
      rescue Refused => error
        { "content" => [ { "type" => "text", "text" => error.message } ], "isError" => true, "resultType" => "complete" }
      rescue StandardError => error
        text = "#{error.class}: #{error.message}"
        { "content" => [ { "type" => "text", "text" => text } ], "structuredContent" => { "error" => text }, "isError" => true, "resultType" => "complete" }
      end
    end
  end
end
