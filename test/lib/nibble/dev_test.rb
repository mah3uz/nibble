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

      Nibble::Dev::Setup.run(root:)
      Nibble::Dev::Setup.run(root:)

      settings = JSON.parse(root.join(".claude/settings.json").read)
      assert_equal [ "Read(.env)", "Edit(/vendor/nibble/**)" ], settings.dig("permissions", "deny"), "running it twice adds the rule once"
      assert_equal "opus", settings["model"]
      assert_equal %w[nibble:dev:mcp], JSON.parse(root.join(".mcp.json").read).dig("mcpServers", "nibble-dev", "args")
    end
  end
end
