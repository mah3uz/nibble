module Nibble
  module Oauth
    class EndpointController < ActionController::API
      before_action { head :not_found unless AgentAccess.enabled? }
      before_action { response.headers["Cache-Control"] = "no-store" }

      rescue_from Nibble::Oauth::Error do |error|
        render json: error.body, status: error.status
      end

      private

      def form = request.request_parameters

      def too_many = render(json: { "error" => "slow_down", "error_description" => "Too many requests. Slow down." }, status: :too_many_requests)
    end
  end
end
