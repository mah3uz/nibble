require_relative "../clean_failures"

class NibbleDevCommand < Rails::Command::Base
  extend CleanFailures
  namespace "nibble:dev"

  desc "seed", "Add realistic demo posts, authors and topics to a development database (safe to re-run)"
  option :posts, type: :numeric, default: 120, desc: "Demo posts to add"
  def seed
    boot_application!
    abort "nibble:dev:seed only runs in development" unless Rails.env.development?

    images = Nibble::Records::Asset.kept.where(kind: "image").select { |asset| asset.width.to_i > asset.height.to_i && asset.width.to_i >= 600 }
    created = Nibble::DemoContent.new(images:, actor: Nibble::User.administrators.first || Nibble::Principal.system).seed(options[:posts])
    Nibble::Events.dispatch_pending
    Nibble::Search.rebuild
    puts "created #{created} posts · #{Nibble::Records::Entry.kept.where(collection: 'posts').group(:status).count.map { |status, count| "#{count} #{status}" }.join(', ')}"
  rescue Nibble::Error => e
    abort e.message
  end

  desc "mcp", "Serve the developer tools to an AI agent over MCP, on standard input and output (development only)"
  def mcp
    ENV["NIBBLE_DEV_TOOLS"] = "1"
    boot_application!
    abort "nibble:dev:mcp runs only in development, with code reloading on" unless Nibble::Dev.allowed?

    Nibble::Dev::McpServer.new.run
  end

  desc "tool NAME [JSON]", "Run one developer tool and print its answer as JSON, e.g. nibble:dev:tool render '{\"path\":\"/\"}'"
  def tool(name = nil, json = "{}")
    ENV["NIBBLE_DEV_TOOLS"] = "1"
    boot_application!
    return puts(JSON.pretty_generate(Nibble::Dev.tools.values.map(&:listing))) unless name

    puts JSON.generate(Nibble::Dev.call(name, JSON.parse(json)))
  rescue Nibble::Dev::Refused, JSON::ParserError => e
    abort e.message
  end

  desc "setup", "Connect the AI tools you choose in this folder to the developer tools, and keep their edits out of vendor/nibble"
  option :tools, desc: "Set up these tools without asking: claude, codex, cursor (comma-separated)"
  def setup
    boot_application!
    tools = options[:tools] ? options[:tools].split(",").map(&:strip).reject(&:empty?) : choose_tools
    return if tools.nil?
    return puts("No tools chosen; nothing written.") if tools.empty?

    Nibble::Dev::Setup.run(tools:).each { |path| puts "  wrote #{path}" }
    puts "Claude Code may not edit vendor/nibble/." if tools.include?("claude")
    puts "Codex reads .codex/config.toml once you trust this project." if tools.include?("codex")
    puts "Agents read AGENTS.md; vendor/nibble/AGENTS.md tells them Nibble's files are not theirs to change."
  rescue Nibble::Error => e
    abort e.message
  end

  no_commands do
    LABELS = { "claude" => "Claude Code", "codex" => "Codex", "cursor" => "Cursor" }.freeze

    def choose_tools
      unless $stdin.tty?
        puts "Not a terminal, so nothing was written. Say which tools to set up:"
        puts "  bin/rails nibble:dev:setup --tools claude,codex,cursor"
        return nil
      end

      found = Nibble::Dev::Setup.detected
      puts "Which AI tools should use this site's developer tools? Files are written only in this folder."
      Nibble::Dev::Setup::TOOLS.each_with_index do |tool, i|
        puts "  #{i + 1}. #{LABELS[tool]}#{' (found on this computer)' if found.include?(tool)}"
      end
      default = found.map { |tool| Nibble::Dev::Setup::TOOLS.index(tool) + 1 }.join(",")
      answer = ask("Numbers, separated by commas (none to skip)", default: default).to_s
      answer.split(/[\s,]+/).reject(&:empty?).filter_map { |n| Nibble::Dev::Setup::TOOLS[n.to_i - 1] if n.to_i.between?(1, 3) }.uniq
    end
  end
end
