module Nibble
  module Cp
    class ApiTokensController < BaseController
      EXPIRIES = { "30" => 30.days, "90" => 90.days, "365" => 365.days }.freeze

      before_action { authorize!("api_tokens.manage") }
      before_action :require_elevated_session, except: :index
      before_action :require_elevated_page, only: :index

      def index
        render inertia: "cp/api_tokens/Index", props: {
          tokens: ApiToken.order(created_at: :desc).map { |token| row(token) },
          scopes: scope_options,
          issued: flash[:issued_token]
        }
      end

      def create
        attrs = params.require(:api_token).permit(:name, :expires_in, scopes: [])
        token, plaintext = ApiToken.issue(name: attrs[:name], scopes: Array(attrs[:scopes]),
          expires_at: EXPIRIES[attrs[:expires_in].to_s]&.from_now, created_by: Nibble::Current.user)
        flash[:issued_token] = { name: token.name, token: plaintext }
        redirect_to "/cp/api-tokens", notice: "Token created. It's shown only once."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to "/cp/api-tokens", inertia: { errors: e.record.errors.to_hash(true).transform_values { |list| list.join(", ") } }
      end

      def destroy
        ApiToken.find(params[:id]).update!(revoked_at: Time.current)
        redirect_to "/cp/api-tokens", notice: "Token revoked."
      end

      private

      def row(token)
        { id: token.id, name: token.name, prefix: token.prefix, scopes: token.scopes,
          expires_at: token.expires_at&.utc&.iso8601, last_used_at: token.last_used_at&.utc&.iso8601,
          created_by: token.created_by&.name, active: token.active? }
      end

      def scope_options
        [ { value: "read", label: "Read live content" }, { value: "preview", label: "Read drafts as well" },
          { value: "health", label: "Check site health (for uptime monitors)" } ] +
          Nibble.schema.collections.map { |item| { value: "manage:#{item.handle}", label: "Manage #{item['title'] || item.handle}" } }
      end
    end
  end
end
