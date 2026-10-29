module Nibble
  module Dev
    # Points the chosen agents at the developer tools, writing only inside the site's folder, and keeps Claude Code's edits out of vendor/nibble.
    module Setup
      SERVER = { "command" => "bin/rails", "args" => %w[nibble:dev:mcp] }.freeze
      DENY = "Edit(/vendor/nibble/**)".freeze

      TOOLS = %w[claude codex cursor].freeze
      CODEX_CONFIG = ".codex/config.toml".freeze
      CODEX_HEADER = "[mcp_servers.nibble-dev]".freeze
      CODEX_SECTION = "#{CODEX_HEADER}\ncommand = \"bin/rails\"\nargs = [\"nibble:dev:mcp\"]\n".freeze

      module_function

      def detected(env: ENV, home: Dir.home)
        paths = env.fetch("PATH", "").split(File::PATH_SEPARATOR)
        on_path = ->(name) { paths.any? { |dir| File.executable?(File.join(dir, name)) && !File.directory?(File.join(dir, name)) } }
        TOOLS.select { |tool| tool == "cursor" ? on_path.("cursor") || File.directory?(File.join(home, ".cursor")) : on_path.(tool) }
      end

      def run(root: Rails.root, tools: TOOLS)
        root = Pathname(root)
        tools = Array(tools).map(&:to_s)
        unknown = tools - TOOLS
        raise Nibble::Error, "Unknown tools: #{unknown.join(', ')}. Choose from #{TOOLS.join(', ')}." if unknown.any?

        written = []
        if tools.include?("claude")
          written << merge(root, ".mcp.json") { |config| with_server(config) }
          written << merge(root, ".claude/settings.json") do |config|
            permissions = config["permissions"].to_h
            config.merge("permissions" => permissions.merge("deny" => Array(permissions["deny"]) | [ DENY ]))
          end
          written += link_skills(root, ".claude/skills")
        end
        if tools.include?("codex")
          written << merge_codex(root)
          written += link_skills(root, ".codex/skills")
        end
        written << merge(root, ".cursor/mcp.json") { |config| with_server(config) } if tools.include?("cursor")
        written
      end

      def remove(root: Rails.root, tools: TOOLS)
        root = Pathname(root)
        tools = Array(tools).map(&:to_s)
        unknown = tools - TOOLS
        raise Nibble::Error, "Unknown tools: #{unknown.join(', ')}. Choose from #{TOOLS.join(', ')}." if unknown.any?

        removed = []
        if tools.include?("claude")
          removed << unmerge(root, ".mcp.json") { |config| without_server(config) }
          removed << unmerge(root, ".claude/settings.json") { |config| without_deny(config) }
          removed += unlink_skills(root, ".claude/skills")
          prune(root, ".claude/skills", ".claude")
        end
        if tools.include?("codex")
          removed << unmerge_codex(root)
          removed += unlink_skills(root, ".codex/skills")
          prune(root, ".codex/skills", ".codex")
        end
        if tools.include?("cursor")
          removed << unmerge(root, ".cursor/mcp.json") { |config| without_server(config) }
          prune(root, ".cursor")
        end
        removed.compact
      end

      def parse_choice(answer)
        words = answer.to_s.split(/[\s,]+/).reject(&:empty?)
        return [] if words.empty? || words == %w[0] || words == %w[none]
        return nil unless words.all? { |word| word.match?(/\A[1-3]\z/) }

        words.map { |word| TOOLS[word.to_i - 1] }.uniq
      end

      def link_skills(root, dir) = Nibble::Skills.bundled.filter_map { |skill| link(root, dir, skill.name) }

      # A link, so each upgrade of vendor/nibble updates the skills; a skill folder the site made itself is left alone.
      def link(root, dir, name)
        path = root.join(dir, name)
        return nil if path.exist? && !path.symlink?

        path.dirname.mkpath
        path.delete if path.symlink?
        path.make_symlink(Pathname("../../vendor/nibble/skills").join(name))
        "#{dir}/#{name}"
      end

      def merge_codex(root)
        file = root.join(CODEX_CONFIG)
        text = file.file? ? file.read : ""
        lines = text.lines
        start = lines.index { |line| line.strip == CODEX_HEADER }
        text =
          if start
            finish = (start + 1...lines.size).find { |i| lines[i].lstrip.start_with?("[") } || lines.size
            (lines[0...start] + [ CODEX_SECTION ] + (finish < lines.size ? [ "\n" ] : []) + lines[finish..]).join
          else
            [ text, (text.empty? || text.end_with?("\n\n") ? "" : (text.end_with?("\n") ? "\n" : "\n\n")), CODEX_SECTION ].join
          end
        file.dirname.mkpath
        file.write(text)
        CODEX_CONFIG
      end

      def with_server(config) = config.merge("mcpServers" => config["mcpServers"].to_h.merge("nibble-dev" => SERVER))

      def without_server(config)
        servers = config["mcpServers"].to_h.except("nibble-dev")
        servers.empty? ? config.except("mcpServers") : config.merge("mcpServers" => servers)
      end

      def without_deny(config)
        permissions = config["permissions"].to_h
        deny = Array(permissions["deny"]) - [ DENY ]
        permissions = deny.empty? ? permissions.except("deny") : permissions.merge("deny" => deny)
        permissions.empty? ? config.except("permissions") : config.merge("permissions" => permissions)
      end

      def unmerge(root, path)
        file = root.join(path)
        return nil unless file.file?

        current = JSON.parse(file.read)
        updated = yield(current)
        return nil if updated == current

        updated.empty? ? file.delete : file.write("#{JSON.pretty_generate(updated)}\n")
        updated.empty? ? "removed #{path}" : "removed nibble-dev from #{path}"
      end

      def unmerge_codex(root)
        file = root.join(CODEX_CONFIG)
        return nil unless file.file?

        lines = file.read.lines
        start = lines.index { |line| line.strip == CODEX_HEADER }
        return nil unless start

        finish = (start + 1...lines.size).find { |i| lines[i].lstrip.start_with?("[") } || lines.size
        start -= 1 while start > 0 && lines[start - 1].strip.empty?
        rest = (lines[0...start] + (start > 0 && finish < lines.size ? [ "\n" ] : []) + lines[finish..]).join
        rest.strip.empty? ? file.delete : file.write(rest)
        rest.strip.empty? ? "removed #{CODEX_CONFIG}" : "removed nibble-dev from #{CODEX_CONFIG}"
      end

      def unlink_skills(root, dir)
        folder = root.join(dir)
        return [] unless folder.directory?

        folder.children.sort.select { |path| path.symlink? && path.readlink.to_s.match?(%r{(\A|/)vendor/nibble/skills/}) }.map do |path|
          path.delete
          "removed #{dir}/#{path.basename}"
        end
      end

      def prune(root, *dirs)
        dirs.each do |dir|
          path = root.join(dir)
          path.rmdir if path.directory? && !path.symlink? && path.children.empty?
        end
      end

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
