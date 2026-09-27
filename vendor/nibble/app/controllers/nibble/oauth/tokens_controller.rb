module Nibble
  module Oauth
    class TokensController < EndpointController
      rate_limit to: 60, within: 1.minute, with: -> { too_many }

      def create
        body = case form["grant_type"]
        when "authorization_code" then Nibble::Oauth.exchange_code!(form, request)
        when "refresh_token" then Nibble::Oauth.refresh!(form)
        when Nibble::Oauth::DEVICE_GRANT
          raise Nibble::Oauth::Error.new("unsupported_grant_type", "device sign-in is off on this site") unless AgentAccess.device_sign_in?

          Nibble::Oauth.poll_device!(form)
        else raise Nibble::Oauth::Error.new("unsupported_grant_type", "grant_type must be authorization_code or refresh_token")
        end
        render json: body
      end

      def revoke
        Nibble::Oauth.revoke!(form["token"])
        head :ok
      end
    end
  end
end
