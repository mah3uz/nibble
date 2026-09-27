module Api
  module V2
    # The management API: every operation in Nibble::Operations, as the person a token acts for.
    class OperationsController < ActionController::API
      before_action { response.headers["Cache-Control"] = "no-store" }
      before_action { response.headers["Nibble-Api-Version"] = Nibble::Operations::VERSION }
      before_action :refuse_query_tokens
      rate_limit to: 600, within: 1.minute, name: "address", with: -> { too_many }
      before_action :authenticate
      rate_limit to: 300, within: 1.minute, name: "grant", by: -> { @grant.id }, with: -> { too_many }

      rescue_from Nibble::Operations::Failure do |failure|
        problem(failure.status, failure.code, failure.message, hint: failure.hint, details: failure.details)
      end

      def index
        render json: { "data" => Nibble::Operations.available(principal).map(&:catalogue), "meta" => meta }
      end

      def create
        operation = Nibble::Operations.find(params[:operation])
        if !request.post? && operation && !operation.read_only
          return problem(:method_not_allowed, "method_not_allowed", "#{operation.name} changes content, so send it as a POST")
        end

        data = Nibble::Operations.call(params[:operation], input, caller: Nibble::Operations::Caller.new(principal:, site: issuer, ip: request.remote_ip))
        render json: { "data" => data, "meta" => meta.merge("operation" => params[:operation]) }
      end

      private

      def input
        source = request.post? ? request.request_parameters : request.query_parameters
        source.to_h.except("operation", "format")
      end

      def principal = Nibble::Principal.new(user: @grant.user, grant: @grant)

      def issuer = Nibble::Oauth.issuer(request)

      def meta = { "site" => issuer, "api_version" => Nibble::Operations::VERSION }

      def refuse_query_tokens
        return unless params.key?(:access_token)

        problem(:bad_request, "invalid_request", "Send the token in the Authorization header, never in the URL.")
      end

      def authenticate
        return head(:not_found) unless Nibble::AgentAccess.enabled?

        token = request.authorization.to_s[/\ABearer (\S+)\z/, 1]
        @grant = Nibble::Oauth.authenticate(token, resources: [ Nibble::Oauth.resources(request)[:api] ])
        return @grant.used!(request.remote_ip) if @grant

        response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{issuer}/.well-known/oauth-protected-resource/api/v2")
        problem(:unauthorized, "unauthorized", "A valid access token is required.", hint: "Sign in with `nibble auth login #{issuer}`.")
      end

      def too_many = problem(:too_many_requests, "slow_down", "Too many requests. Slow down.")

      def problem(status, code, detail, hint: nil, details: nil)
        code_number = Rack::Utils.status_code(status)
        render status:, content_type: "application/problem+json", json: {
          "type" => "https://nibble.ink/problems/#{code}", "title" => Rack::Utils::HTTP_STATUS_CODES[code_number], "status" => code_number,
          "code" => code, "detail" => detail, "hint" => hint, "details" => details
        }.compact
      end
    end
  end
end
