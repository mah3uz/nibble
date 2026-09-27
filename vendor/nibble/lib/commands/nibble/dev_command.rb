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
    boot_application!
    abort "nibble:dev:mcp runs only in development, with code reloading on" unless Nibble::Dev.allowed?

    Nibble::Dev::McpServer.new.run
  end

  desc "tool NAME [JSON]", "Run one developer tool and print its answer as JSON, e.g. nibble:dev:tool render '{\"path\":\"/\"}'"
  def tool(name = nil, json = "{}")
    boot_application!
    return puts(JSON.pretty_generate(Nibble::Dev.tools.values.map(&:listing))) unless name

    puts JSON.generate(Nibble::Dev.call(name, JSON.parse(json)))
  rescue Nibble::Dev::Refused, JSON::ParserError => e
    abort e.message
  end

  desc "setup", "Connect AI agents in this folder to the developer tools, and keep their edits out of vendor/nibble"
  def setup
    boot_application!
    Nibble::Dev::Setup.run.each { |path| puts "  wrote #{path}" }
    puts "Claude Code and Cursor: .mcp.json and .cursor/mcp.json name the nibble-dev server; Claude Code may not edit vendor/nibble/."
    puts "Codex: codex mcp add nibble-dev -- bin/rails nibble:dev:mcp"
    puts "Agents read AGENTS.md; vendor/nibble/AGENTS.md tells them Nibble's files are not theirs to change."
  end
end
