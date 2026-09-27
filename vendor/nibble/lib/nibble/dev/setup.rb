module Nibble
  module Dev
    # Points the agents working in a site at the developer tools, and keeps Claude Code's edits out of vendor/nibble.
    module Setup
      SERVER = { "command" => "bin/rails", "args" => %w[nibble:dev:mcp] }.freeze
      DENY = "Edit(/vendor/nibble/**)".freeze

      module_function

      def run(root: Rails.root)
        root = Pathname(root)
        written = []
        written << merge(root, ".mcp.json") { |config| with_server(config) }
        written << merge(root, ".cursor/mcp.json") { |config| with_server(config) }
        written << merge(root, ".claude/settings.json") do |config|
          permissions = config["permissions"].to_h
          config.merge("permissions" => permissions.merge("deny" => Array(permissions["deny"]) | [ DENY ]))
        end
        written
      end

      def with_server(config) = config.merge("mcpServers" => config["mcpServers"].to_h.merge("nibble-dev" => SERVER))

      def merge(root, path)
        file = root.join(path)
        current = file.file? ? JSON.parse(file.read) : {}
        file.dirname.mkpath
        file.write("#{JSON.pretty_generate(yield(current))}\n")
        path
      end
    end
  end
end
