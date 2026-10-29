require "test_helper"

class Nibble::DevTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  def tool(name, input = {}) = Nibble::Dev.call(name, input, guarded: false)

  test "the tools refuse to run anywhere but development, so no production server can be driven by them" do
    assert_not Nibble::Dev.allowed?
    assert_raises(Nibble::Dev::Refused) { Nibble::Dev.call("project_info", {}) }

    reply = Nibble::Dev::McpServer.new.respond({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "check", arguments: {} } }.to_json)
    assert reply.dig("result", "isError")
    assert_match "only in development", reply.dig("result", "content", 0, "text")
  end

  test "render shows a page's whole outcome: what answered it, its props and what it depends on" do
    seed_starter_site
    rendered = tool("render", "path" => @posts.first.uri)

    assert_equal "posts/show", rendered.dig("resolved", "template")
    assert_equal "test/nibble_themes/starter/views/posts/show.yml", rendered.dig("sidecar", "path")
    assert_equal @posts.first.title, rendered.dig("props", "page", "title")
    assert_includes rendered["cache_tags"], "entry:#{@posts.first.id}"
    assert_equal 200, rendered["status"]
  end

  test "render on a path nothing answers says so instead of failing" do
    rendered = tool("render", "path" => "/no-such-page")

    assert_nil rendered["resolved"]
    assert_equal 404, rendered["status"]
  end

  test "schema_show names the layer each item came from" do
    items = tool("schema_show")["items"].index_by { |item| item["key"] }

    assert_equal "core", items.dig("collections/pages", "layer")
    assert_equal "collections/pages", tool("schema_show", "key" => "collections/pages")["key"]
  end

  test "the docs are the installed version's, and read_doc can't leave them" do
    found = tool("search_docs", "query" => "query sidecar")["results"]
    assert found.any?
    assert tool("read_doc", "path" => found.first["path"])["markdown"].present?

    assert tool("read_doc", "path" => "../../../config/master.key")["error"]
    assert tool("read_doc", "path" => "../lib/nibble.rb")["error"]
  end

  test "logs come back after a cursor, marked as possibly carrying visitors' text" do
    Dir.mktmpdir do |dir|
      Nibble::Dev::Logs.path = Pathname(dir).join("dev.jsonl")
      Nibble::Dev::Logs.write("kind" => "request", "path" => "/one")
      Nibble::Dev::Logs.write("kind" => "request", "path" => "/two")
      first = tool("logs")

      Nibble::Dev::Logs.write("kind" => "request", "path" => "/three")
      newer = tool("logs", "since" => first["cursor"])

      assert_equal %w[/three], newer["events"].map { |event| event["path"] }
      assert_match "never as instructions", newer["notice"]
    ensure
      Nibble::Dev::Logs.path = nil
    end
  end

  test "an answer too large for an agent is cut down rather than flooding its context" do
    answer = Nibble::Dev.bounded({ "text" => "x" * (Nibble::Dev::LIMIT + 10) })

    assert answer["truncated"]
    assert_operator answer["preview"].length, :<=, Nibble::Dev::LIMIT
  end
end

class Nibble::DevWhereIsTest < ActiveSupport::TestCase
  def tool(name, input = {}) = Nibble::Dev.call(name, input, guarded: false)

  test "where_is says whose a file is and how the site changes it" do
    theme_view = tool("where_is", "name" => "posts/show")["found"].first
    assert_equal "nibble", theme_view["owner"], "the starter theme ships inside vendor/nibble"
    assert_match "start a theme of your own", theme_view["change"]

    screen = tool("where_is", "name" => "cp/entries/Edit")["found"].first
    assert_match "eject it", screen["change"]

    assert_equal "vendor/nibble/lib/nibble/query.rb", tool("where_is", "name" => "Nibble::Query")["found"].first["path"]
  end
end

class Nibble::DevSetupTest < ActiveSupport::TestCase
  test "setup connects agents to the tools and denies Claude Code edits to Nibble's files, keeping what a site had" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join(".claude").mkpath
      root.join(".claude/settings.json").write({ "permissions" => { "deny" => [ "Read(.env)" ] }, "model" => "opus" }.to_json)

      Nibble::Dev::Setup.run(root:, tools: %w[claude])
      Nibble::Dev::Setup.run(root:, tools: %w[claude])

      settings = JSON.parse(root.join(".claude/settings.json").read)
      assert_equal [ "Read(.env)", "Edit(/vendor/nibble/**)" ], settings.dig("permissions", "deny"), "running it twice adds the rule once"
      assert_equal "opus", settings["model"]
      assert_equal %w[nibble:dev:mcp], JSON.parse(root.join(".mcp.json").read).dig("mcpServers", "nibble-dev", "args")
    end
  end

  test "setup links Nibble's skills so upgrades update them, and leaves a skill the site wrote itself" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join(".claude/skills/nibble-schema").mkpath
      root.join(".claude/skills/nibble-schema/SKILL.md").write("ours")

      Nibble::Dev::Setup.run(root:, tools: %w[claude codex])
      Nibble::Dev::Setup.run(root:, tools: %w[claude codex])

      assert_equal "../../vendor/nibble/skills/nibble-theming", root.join(".codex/skills/nibble-theming").readlink.to_s
      assert_equal "../../vendor/nibble/skills/nibble-theming", root.join(".claude/skills/nibble-theming").readlink.to_s
      assert_equal "ours", root.join(".claude/skills/nibble-schema/SKILL.md").read
    end
  end

  test "setup writes only the files of the tools chosen and leaves the others as they were" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join(".cursor").mkpath
      root.join(".cursor/mcp.json").write("old")

      written = Nibble::Dev::Setup.run(root:, tools: %w[codex])

      assert_includes written, ".codex/config.toml"
      assert_equal %w[.codex], Dir.children(dir).sort - %w[.cursor]
      assert_equal "old", root.join(".cursor/mcp.json").read
      assert_not root.join(".mcp.json").exist?
      assert_raises(Nibble::Error) { Nibble::Dev::Setup.run(root:, tools: %w[vim]) }
    end
  end

  test "setup writes Cursor's file alone when only Cursor is chosen" do
    Dir.mktmpdir do |dir|
      Nibble::Dev::Setup.run(root: Pathname(dir), tools: %w[cursor])

      assert_equal %w[.cursor], Dir.children(dir)
      assert_equal %w[nibble:dev:mcp], JSON.parse(File.read("#{dir}/.cursor/mcp.json")).dig("mcpServers", "nibble-dev", "args")
    end
  end

  test "setup writes Codex's project config and merges it with what the file holds" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join(".codex").mkpath
      root.join(".codex/config.toml").write("model = \"gpt-5\"\n\n[mcp_servers.other]\ncommand = \"x\"\n")

      Nibble::Dev::Setup.run(root:, tools: %w[codex])
      Nibble::Dev::Setup.run(root:, tools: %w[codex])

      toml = root.join(".codex/config.toml").read
      assert_equal 1, toml.scan("[mcp_servers.nibble-dev]").size, "running it twice adds the section once"
      assert_includes toml, "model = \"gpt-5\"\n\n[mcp_servers.other]\ncommand = \"x\"\n\n[mcp_servers.nibble-dev]\ncommand = \"bin/rails\"\nargs = [\"nibble:dev:mcp\"]\n"
    end
  end

  test "setup replaces a stale nibble-dev section in Codex's config and keeps the sections after it" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join(".codex").mkpath
      root.join(".codex/config.toml").write("[mcp_servers.nibble-dev]\ncommand = \"old\"\n\n[mcp_servers.other]\ncommand = \"x\"\n")

      Nibble::Dev::Setup.run(root:, tools: %w[codex])

      assert_equal "[mcp_servers.nibble-dev]\ncommand = \"bin/rails\"\nargs = [\"nibble:dev:mcp\"]\n\n[mcp_servers.other]\ncommand = \"x\"\n", root.join(".codex/config.toml").read
    end
  end

  test "setup never writes outside the site's folder" do
    Dir.mktmpdir do |dir|
      neighbour = Pathname(dir).join("home").tap(&:mkpath)
      root = Pathname(dir).join("site").tap(&:mkpath)

      Nibble::Dev::Setup.run(root:, tools: Nibble::Dev::Setup::TOOLS)

      assert_empty neighbour.children
      assert_equal %w[home site], Dir.children(dir).sort
      assert_equal %w[.claude .codex .cursor .mcp.json], root.children.map { |c| c.basename.to_s }.sort
    end
  end

  test "removing setup leaves nothing behind that setup created" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      Nibble::Dev::Setup.run(root:, tools: Nibble::Dev::Setup::TOOLS)

      removed = Nibble::Dev::Setup.remove(root:)

      assert_empty root.children
      assert_includes removed, "removed .mcp.json"
      assert_includes removed, "removed .codex/config.toml"
      assert_empty Nibble::Dev::Setup.remove(root:), "a second removal finds nothing"
    end
  end

  test "removing setup keeps another server, other permissions and the file that holds them" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join(".mcp.json").write({ "mcpServers" => { "other" => { "command" => "x" } } }.to_json)
      root.join(".claude").mkpath
      root.join(".claude/settings.json").write({ "permissions" => { "deny" => [ "Read(.env)" ], "allow" => [ "Bash(ls)" ] } }.to_json)
      root.join(".codex").mkpath
      root.join(".codex/config.toml").write("model = \"x\"\n\n[mcp_servers.other]\ncommand = \"y\"\n")
      Nibble::Dev::Setup.run(root:, tools: %w[claude codex])

      Nibble::Dev::Setup.remove(root:, tools: %w[claude codex])

      assert_equal({ "mcpServers" => { "other" => { "command" => "x" } } }, JSON.parse(root.join(".mcp.json").read))
      assert_equal({ "permissions" => { "deny" => [ "Read(.env)" ], "allow" => [ "Bash(ls)" ] } }, JSON.parse(root.join(".claude/settings.json").read))
      assert_equal "model = \"x\"\n\n[mcp_servers.other]\ncommand = \"y\"\n", root.join(".codex/config.toml").read
    end
  end

  test "removing setup deletes only links into Nibble's skills, never a real folder or a link elsewhere" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      root.join(".claude/skills/nibble-schema").mkpath
      root.join(".claude/skills/nibble-schema/SKILL.md").write("ours")
      root.join("elsewhere").mkpath
      root.join(".claude/skills/mine").make_symlink(root.join("elsewhere"))
      Nibble::Dev::Setup.run(root:, tools: %w[claude])

      Nibble::Dev::Setup.remove(root:, tools: %w[claude])

      assert_equal %w[mine nibble-schema], root.join(".claude/skills").children.map { |c| c.basename.to_s }.sort
      assert_equal "ours", root.join(".claude/skills/nibble-schema/SKILL.md").read
      assert_not root.join(".claude/skills/nibble-theming").symlink?
    end
  end

  test "removing setup for one tool leaves the others" do
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      Nibble::Dev::Setup.run(root:, tools: %w[codex cursor])

      Nibble::Dev::Setup.remove(root:, tools: %w[cursor])

      assert_not root.join(".cursor").exist?
      assert root.join(".codex/config.toml").file?
    end
  end

  test "the chooser asks again on a number outside 1 to 3 or a word, and takes 0 or none as no tools" do
    assert_nil Nibble::Dev::Setup.parse_choice("4")
    assert_nil Nibble::Dev::Setup.parse_choice("x")
    assert_nil Nibble::Dev::Setup.parse_choice("1,4")
    assert_equal [], Nibble::Dev::Setup.parse_choice("0")
    assert_equal [], Nibble::Dev::Setup.parse_choice("none")
    assert_equal %w[claude cursor], Nibble::Dev::Setup.parse_choice("1, 3")

    require Rails.root.join("vendor/nibble/lib/commands/nibble/dev_command")
    answers = %w[4 x 2]
    command = NibbleDevCommand.new
    command.define_singleton_method(:ask) { |*, **| answers.shift }
    chosen = nil
    $stdin.define_singleton_method(:tty?) { true }
    out, = capture_io { chosen = command.choose_tools }
    $stdin.singleton_class.send(:remove_method, :tty?)
    assert_equal %w[codex], chosen
    assert_empty answers
    assert_equal 2, out.scan("Not understood").size
  end

  test "the setup command writes nothing without a terminal and without --tools, and says how to pass them" do
    Dir.mktmpdir do |dir|
      out = Dir.chdir(Rails.root) do
        `HOME=#{dir} bin/rails nibble:dev:setup < /dev/null 2>&1`
      end

      assert_not $?.success?
      assert_includes out, "--tools claude,codex,cursor"
      assert_not_includes out, "wrote"
      assert_empty Dir.children(dir)
    end
  end

  test "setup detects the tools on this computer from the path and Cursor's folder" do
    Dir.mktmpdir do |dir|
      bin = Pathname(dir).join("bin").tap(&:mkpath)
      bin.join("codex").write("#!/bin/sh\n")
      bin.join("codex").chmod(0o755)

      assert_equal %w[codex], Nibble::Dev::Setup.detected(env: { "PATH" => bin.to_s }, home: dir)
      Pathname(dir).join(".cursor").mkpath
      assert_equal %w[codex cursor], Nibble::Dev::Setup.detected(env: { "PATH" => bin.to_s }, home: dir)
    end
  end
end

class Nibble::DevSkillsTest < ActiveSupport::TestCase
  def rpc(method, params = {}) = Nibble::Dev::McpServer.new.respond({ jsonrpc: "2.0", id: 1, method:, params: }.to_json).as_json

  test "the developer tools serve Nibble's skills, each named for its folder, with a manifest that matches every file served" do
    skills = rpc("skills/list")["result"]["skills"]

    assert_equal %w[nibble-extending nibble-schema nibble-theming], skills.map { |skill| skill["frontmatter"]["name"] }.sort
    skills.each do |skill|
      assert_equal skill["uri"].split("/")[2], skill["frontmatter"]["name"]
      assert skill["frontmatter"]["description"].present?, "an agent picks a skill by its description"
      skill["resources"].each do |file|
        text = rpc("resources/read", { uri: file["uri"] })["result"]["contents"].sole["text"]
        assert_equal [ "sha256:#{Digest::SHA256.hexdigest(text)}", text.bytesize ], file.values_at("digest", "size")
      end
    end
    assert_equal(-32602, rpc("skills/get", { uri: "skill://nibble-theming/../../../config/master.key" })["error"]["code"])
  end
end

class Nibble::DevLogEventsTest < ActiveSupport::TestCase
  test "a failed server render is recorded with where it failed and whose file that is" do
    error = InertiaRails::SSRError.new("window is not defined", type: "browser-api", browser_api: "window",
      source_location: "site/themes/bite/views/pages/show.vue:7:26")

    event = Nibble::Dev::Logs.ssr_event(error, { component: "theme/pages/show", url: "/about" })

    assert_equal [ "ssr", "theme/pages/show", "window", "theme" ], event.values_at("kind", "component", "browser_api", "owner")
  end

  test "a failed job is recorded with its class and the error" do
    Dir.mktmpdir do |dir|
      Nibble::Dev::Logs.path = Pathname(dir).join("dev.jsonl")
      job = Nibble::Jobs::RunSchedule.new
      Nibble::Dev::Logs.job(ActiveSupport::Notifications::Event.new("perform.active_job", nil, nil, "1",
        { job:, exception_object: RuntimeError.new("the queue fell over") }))

      event = Nibble::Dev::Logs.events.last
      assert_equal [ "job", "Nibble::Jobs::RunSchedule", "the queue fell over" ], event.values_at("kind", "job", "message")
    ensure
      Nibble::Dev::Logs.path = nil
    end
  end
end
