module Nibble
  # The site's own OAuth authorization server, for the apps people connect: public clients, PKCE, nothing else.
  module Oauth
    class Error < StandardError
      attr_reader :code, :status

      def initialize(code, description, status: :bad_request)
        @code = code
        @status = status
        super(description)
      end

      def body = { "error" => code, "error_description" => message }
    end

    METADATA_TTL = 1.day
    METADATA_BYTES = 8.kilobytes
    GRANT_TYPES = %w[authorization_code refresh_token].freeze
    DEVICE_GRANT = "urn:ietf:params:oauth:grant-type:device_code".freeze

    module_function

    def issuer(request) = Nibble.config.url.presence&.to_s&.chomp("/") || request.base_url

    def resources(request) = { mcp: "#{issuer(request)}/api/v1/mcp", api: "#{issuer(request)}/api/v1" }

    def resource!(request, requested)
      return resources(request)[:mcp] if requested.blank?
      raise Error.new("invalid_target", "resource isn't this site") unless resources(request).value?(requested.to_s)

      requested.to_s
    end

    def server_metadata(request)
      base = issuer(request)
      {
        "issuer" => base,
        "authorization_endpoint" => "#{base}/oauth/authorize",
        "token_endpoint" => "#{base}/oauth/token",
        "registration_endpoint" => "#{base}/oauth/register",
        "revocation_endpoint" => "#{base}/oauth/revoke",
        "device_authorization_endpoint" => AgentAccess.device_sign_in? ? "#{base}/oauth/device_authorization" : nil,
        "response_types_supported" => %w[code],
        "response_modes_supported" => %w[query],
        "grant_types_supported" => GRANT_TYPES + (AgentAccess.device_sign_in? ? [ DEVICE_GRANT ] : []),
        "code_challenge_methods_supported" => %w[S256],
        "token_endpoint_auth_methods_supported" => %w[none],
        "revocation_endpoint_auth_methods_supported" => %w[none],
        "client_id_metadata_document_supported" => true,
        "authorization_response_iss_parameter_supported" => true
      }.compact
    end

    def resource_metadata(request, resource)
      { "resource" => resource, "authorization_servers" => [ issuer(request) ], "bearer_methods_supported" => %w[header],
        "resource_name" => site_name }
    end

    def site_name
      Records::GlobalSet.find_by(handle: "site", locale: Nibble.config.default_locale.code)&.values&.dig("name").presence || "Nibble"
    end

    def client!(client_id)
      id = client_id.to_s
      raise Error.new("invalid_client", "client_id is required", status: :unauthorized) if id.empty?
      return OauthClient.cli if id == OauthClient::CLI_ID
      return metadata_client!(id) if id.start_with?("https://")

      OauthClient.find_by(client_id: id, kind: "registered") or raise Error.new("invalid_client", "unknown client", status: :unauthorized)
    end

    def metadata_client!(url)
      existing = OauthClient.find_by(client_id: url)
      return existing if existing&.fetched_at&.after?(METADATA_TTL.ago)

      document = fetch_metadata(url)
      client = existing || OauthClient.new(client_id: url, kind: "metadata")
      client.update!(name: document["client_name"].to_s.strip.first(100).presence || URI.parse(url).host,
        client_uri: document["client_uri"].to_s.first(500).presence, redirect_uris: Array(document["redirect_uris"]).map(&:to_s),
        fetched_at: Time.current)
      client
    rescue ActiveRecord::RecordInvalid => error
      raise Error.new("invalid_client", "the client's metadata document is unusable: #{error.record.errors.full_messages.to_sentence}",
        status: :unauthorized)
    end

    def fetch_metadata(url)
      uri = URI.parse(url)
      raise Error.new("invalid_client", "client_id must be an https URL with a path", status: :unauthorized) if uri.path.to_s.length < 2 || uri.fragment

      response = Outbound.request(:get, url, purpose: "oauth_client_metadata", timeout: 5, max_bytes: METADATA_BYTES, redirects: 0)
      document = response.ok? ? response.json : nil
      raise Error.new("invalid_client", "the client's metadata document couldn't be read", status: :unauthorized) unless document.is_a?(Hash)
      raise Error.new("invalid_client", "the metadata document names a different client_id", status: :unauthorized) if document["client_id"] != url
      unless [ nil, "none" ].include?(document["token_endpoint_auth_method"])
        raise Error.new("invalid_client", "only public clients can connect", status: :unauthorized)
      end

      document
    rescue URI::InvalidURIError, Outbound::Refused, Outbound::Failed => error
      raise Error.new("invalid_client", "the client's metadata document couldn't be fetched: #{error.message}", status: :unauthorized)
    end

    def register!(params, ip:)
      unless [ nil, "none" ].include?(params["token_endpoint_auth_method"])
        raise Error.new("invalid_client_metadata", "only public clients can register (token_endpoint_auth_method: none)")
      end
      unless (Array(params["grant_types"].presence || GRANT_TYPES) - GRANT_TYPES - [ DEVICE_GRANT ]).empty?
        raise Error.new("invalid_client_metadata", "grant_types may only be #{GRANT_TYPES.to_sentence}")
      end
      raise Error.new("invalid_client_metadata", "response_types may only be code") unless (Array(params["response_types"].presence || %w[code]) - %w[code]).empty?

      OauthClient.where(kind: "registered").where(created_at: ..1.day.ago).where.missing(:grants).delete_all
      client = OauthClient.create!(client_id: "nibble_client_#{SecureRandom.base58(24)}", kind: "registered", registered_ip: ip,
        name: params["client_name"].to_s.strip.first(100).presence || "Unnamed app", client_uri: params["client_uri"].to_s.first(500).presence,
        redirect_uris: Array(params["redirect_uris"]).map(&:to_s))
      { "client_id" => client.client_id, "client_id_issued_at" => client.created_at.to_i, "client_name" => client.name,
        "redirect_uris" => client.redirect_uris, "token_endpoint_auth_method" => "none", "grant_types" => GRANT_TYPES,
        "response_types" => %w[code] }
    rescue ActiveRecord::RecordInvalid => error
      raise Error.new("invalid_redirect_uri", error.record.errors.full_messages.to_sentence)
    end

    def exchange_code!(params, request)
      code = OauthCode.find_by_code(params["code"]) or raise Error.new("invalid_grant", "the code isn't valid")
      grant = code.grant
      if code.used_at
        grant.revoke!
        raise Error.new("invalid_grant", "the code was already used, so everything issued from it is revoked")
      end
      code.update!(used_at: Time.current)
      raise Error.new("invalid_grant", "the code has expired") if code.expired? || !grant.active?
      raise Error.new("invalid_grant", "the code was issued to another client") if grant.oauth_client&.client_id != params["client_id"].to_s
      raise Error.new("invalid_grant", "redirect_uri doesn't match the authorization request") if code.redirect_uri != params["redirect_uri"].to_s
      raise Error.new("invalid_grant", "code_verifier doesn't match the code_challenge") unless code.verifies?(params["code_verifier"])
      raise Error.new("invalid_target", "resource doesn't match the authorization request") if params["resource"].present? && params["resource"] != code.resource

      token_response(grant, code.resource)
    end

    def refresh!(params)
      token = OauthToken.find_by_token(params["refresh_token"], kinds: %w[refresh]) or raise Error.new("invalid_grant", "the refresh token isn't valid")
      grant = token.grant
      raise Error.new("invalid_grant", "the refresh token was issued to another client") if grant.oauth_client&.client_id != params["client_id"].to_s
      if token.reused?
        grant.revoke!
        raise Error.new("invalid_grant", "the refresh token was already used, so the app has been disconnected")
      end
      raise Error.new("invalid_grant", "the refresh token has expired or been revoked") unless token.usable?

      token.update!(used_at: Time.current) if token.used_at.nil?
      token_response(grant, token.resource)
    end

    def poll_device!(params)
      device = DeviceCode.find_by_device_code(params["device_code"]) or raise Error.new("invalid_grant", "the device code isn't valid")
      raise Error.new("invalid_grant", "the device code was issued to another client") if device.oauth_client.client_id != params["client_id"].to_s
      raise Error.new("expired_token", "the code has expired; start again") if device.expired?

      too_soon = device.last_polled_at&.after?(DeviceCode::INTERVAL.seconds.ago)
      device.update_column(:last_polled_at, Time.current)
      case device.status
      when "denied" then raise Error.new("access_denied", "the request was declined")
      when "used" then raise Error.new("invalid_grant", "the device code was already used")
      when "pending" then raise Error.new(too_soon ? "slow_down" : "authorization_pending", "waiting for someone to approve it")
      end

      device.update!(status: "used")
      token_response(device.grant, device.resource)
    end

    def revoke!(plaintext)
      OauthToken.find_by_token(plaintext, kinds: OauthToken::KINDS)&.grant&.revoke!
    end

    def token_response(grant, resource)
      { "access_token" => OauthToken.issue(grant, "access", resource:), "token_type" => "Bearer",
        "expires_in" => OauthToken::ACCESS_LIFETIME.to_i, "refresh_token" => OauthToken.issue(grant, "refresh", resource:) }
    end

    def authenticate(plaintext, resources:)
      token = OauthToken.find_by_token(plaintext, kinds: %w[access ci])
      return nil unless token&.usable? && (token.kind == "ci" || resources.include?(token.resource))
      return nil unless AgentAccess.enabled?

      token.grant
    end

    def redirect_with(uri, params)
      parsed = URI.parse(uri)
      parsed.query = [ parsed.query.presence, URI.encode_www_form(params.compact) ].compact.join("&")
      parsed.to_s
    end
  end
end
