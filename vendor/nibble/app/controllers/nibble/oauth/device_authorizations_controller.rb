module Nibble
  module Oauth
    class DeviceAuthorizationsController < EndpointController
      before_action { head :not_found unless AgentAccess.device_sign_in? }
      rate_limit to: 10, within: 10.minutes, with: -> { too_many }

      def create
        client = Nibble::Oauth.client!(form["client_id"])
        device, code = DeviceCode.issue(oauth_client: client, resource: Nibble::Oauth.resource!(request, form["resource"]), ip: request.remote_ip)
        verification = "#{Nibble::Oauth.issuer(request)}/cp/device"
        render json: { "device_code" => code, "user_code" => device.display_code, "verification_uri" => verification,
                       "verification_uri_complete" => "#{verification}?code=#{device.display_code}",
                       "expires_in" => DeviceCode::LIFETIME.to_i, "interval" => DeviceCode::INTERVAL }
      end
    end
  end
end
