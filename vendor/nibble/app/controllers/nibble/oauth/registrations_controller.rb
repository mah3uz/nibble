module Nibble
  module Oauth
    class RegistrationsController < EndpointController
      rate_limit to: 10, within: 1.hour, with: -> { too_many }

      def create
        render json: Nibble::Oauth.register!(params.to_unsafe_h, ip: request.remote_ip), status: :created
      end
    end
  end
end
