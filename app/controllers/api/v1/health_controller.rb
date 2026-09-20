module Api
  module V1
    class HealthController < BaseController
      def show
        return error(:forbidden, "This token can't check health.") unless @token.allows?("health")

        checks = Nibble::Health.run
        status = Nibble::Health.status(checks)
        response.headers["Cache-Control"] = "no-store"
        render json: { status:, checked_at: Time.current.utc.iso8601, checks: checks.map(&:to_h) },
          status: status == "down" ? :service_unavailable : :ok
      end
    end
  end
end
