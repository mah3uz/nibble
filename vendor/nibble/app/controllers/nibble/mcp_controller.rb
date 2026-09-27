module Nibble
  # The site's MCP server: stateless JSON-RPC over HTTP, serving Nibble::Operations as tools to a person's connected apps.
  class McpController < ActionController::API
    include Nibble::BearerAuthentication

    CURRENT = "2026-07-28".freeze
    HANDSHAKE = %w[2025-11-25 2025-06-18 2025-03-26].freeze
    LIST_TTL = 60_000

    class RpcError < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    before_action { response.headers["Cache-Control"] = "no-store" }
    before_action { head :not_found unless Nibble::AgentAccess.enabled? }
    before_action :refuse_foreign_origin
    rate_limit to: 600, within: 1.minute, name: "address", with: -> { head :too_many_requests }
    before_action :authenticate
    rate_limit to: 300, within: 1.minute, name: "grant", by: -> { @grant.id }, with: -> { head :too_many_requests }

    def create
      message = JSON.parse(request.raw_post)
      return reply(nil, error: [ -32600, "send one JSON-RPC message per request" ]) unless message.is_a?(Hash)
      return head(:accepted) unless message.key?("id")

      reply(message["id"], result: answer(message["method"].to_s, message["params"].to_h))
    rescue JSON::ParserError
      reply(nil, error: [ -32700, "the body isn't JSON" ], status: :bad_request)
    rescue RpcError => error
      reply(message["id"], error: [ error.code, error.message ])
    end

    def elsewhere = head(:method_not_allowed)

    private

    def answer(method, params)
      case method
      when "initialize" then handshake(params)
      when "server/discover" then discover
      when "ping", "logging/setLevel" then {}
      when "tools/list" then listing("tools" => tools)
      when "tools/call" then call_tool(params)
      when "resources/list" then listing("resources" => skills.map { |skill| Nibble::Skills.resource(skill) })
      when "resources/templates/list" then listing("resourceTemplates" => [])
      when "resources/read" then listing("contents" => [ Nibble::Skills.read(skills, params["uri"].to_s) ])
      when "skills/list" then listing("skills" => skills.map { |skill| Nibble::Skills.entry(skill) })
      when "skills/get" then listing("skill" => Nibble::Skills.get(skills, params["uri"].to_s))
      when "prompts/list" then listing("prompts" => [])
      else raise RpcError.new(-32601, "#{method} isn't supported")
      end
    rescue Nibble::Skills::Unknown => error
      raise RpcError.new(-32602, error.message)
    end

    def handshake(params)
      requested = params["protocolVersion"].to_s
      { "protocolVersion" => HANDSHAKE.include?(requested) ? requested : HANDSHAKE.first, "capabilities" => capabilities,
        "serverInfo" => server_info, "instructions" => instructions }
    end

    def discover
      { "supportedVersions" => [ CURRENT, *HANDSHAKE ], "capabilities" => capabilities, "serverInfo" => server_info,
        "instructions" => instructions, "resultType" => "complete" }
    end

    def capabilities = { "tools" => { "listChanged" => false }, "resources" => { "listChanged" => false }, "extensions" => { Nibble::Skills::EXTENSION => {} } }

    def server_info = { "name" => "nibble", "title" => Nibble::Oauth.site_name, "version" => Nibble::VERSION }

    def instructions = Nibble::AgentGuide.instructions(site: Nibble::Oauth.site_name, url: Nibble::Oauth.issuer(request))

    def listing(body) = body.merge("ttlMs" => LIST_TTL, "cacheScope" => "private", "resultType" => "complete")

    def tools
      Nibble::Operations.available(grant_principal(@grant)).sort_by(&:name).map do |operation|
        { "name" => operation.name, "title" => operation.title, "description" => operation.description,
          "inputSchema" => operation.input, "annotations" => operation.annotations.merge("title" => operation.title) }
      end
    end

    def call_tool(params)
      name = params["name"].to_s
      raise RpcError.new(-32602, "there is no tool called #{name}") unless Nibble::Operations.find(name)

      data = Nibble::Operations.call(name, params["arguments"].to_h, caller: operations_caller(@grant))
      { "content" => [ { "type" => "text", "text" => data.to_json } ], "structuredContent" => data, "isError" => false, "resultType" => "complete" }
    rescue Nibble::Operations::Failure => failure
      text = [ "#{failure.code}: #{failure.message}", failure.hint ].compact.join("\n")
      { "content" => [ { "type" => "text", "text" => text } ], "structuredContent" => failure.to_h, "isError" => true, "resultType" => "complete" }
    end

    def skills
      @skills ||= begin
        site, url = Nibble::Oauth.site_name, Nibble::Oauth.issuer(request)
        [ Nibble::Skills::Skill.new(Nibble::AgentGuide.name(site), { "SKILL.md" => Nibble::AgentGuide.skill(site:, url:) }) ]
      end
    end

    def reply(id, result: nil, error: nil, status: :ok)
      body = { "jsonrpc" => "2.0", "id" => id }
      error ? body["error"] = { "code" => error.first, "message" => error.last } : body["result"] = result
      render json: body, status:
    end

    def refuse_foreign_origin
      origin = request.headers["Origin"]
      head :forbidden if origin.present? && origin != Nibble::Oauth.issuer(request)
    end

    def authenticate
      @grant = bearer_grant(:mcp)
      return if @grant

      challenge("mcp")
      render json: { "error" => "unauthorized", "error_description" => "Connect this app to the site first." }, status: :unauthorized
    end
  end
end
