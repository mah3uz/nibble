module Nibble
  # Who a request to the management API or the MCP endpoint acts as: the grant behind a bearer token for this resource.
  module BearerAuthentication
    extend ActiveSupport::Concern

    private

    def bearer_grant(resource)
      token = request.authorization.to_s[/\ABearer (\S+)\z/, 1]
      grant = Nibble::Oauth.authenticate(token, resources: [ Nibble::Oauth.resources(request)[resource] ])
      grant&.used!(request.remote_ip)
      grant
    end

    def challenge(path)
      response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{Nibble::Oauth.issuer(request)}/.well-known/oauth-protected-resource/#{path}")
    end

    def grant_principal(grant) = Nibble::Principal.new(user: grant.user, grant:)

    def operations_caller(grant)
      Nibble::Operations::Caller.new(principal: grant_principal(grant), site: Nibble::Oauth.issuer(request), ip: request.remote_ip)
    end
  end
end
