module Nibble
  module Cp
    class ConnectedAppsController < BaseController
      EXPIRIES = { "7" => 7.days, "30" => 30.days, "90" => 90.days }.freeze

      before_action :require_elevated_session, only: :create
      before_action :require_elevated_session, only: :update, if: :changes_access?

      def index
        grants = Nibble::Current.user.grants.includes(:oauth_client).order(created_at: :desc)
        render inertia: "cp/account/Apps", props: {
          enabled: AgentAccess.enabled?,
          site_approvals: AgentAccess.approvals,
          can_connect: Nibble::Access.can?(Nibble::Current.user, "apps.connect"),
          elevated: elevated?,
          apps: grants.select(&:active?).map { |grant| row(grant) },
          approvals: Nibble::Approval.where(grant: grants.select(&:active?), status: "pending").where("expires_at > ?", Time.current)
            .order(created_at: :desc).includes(:grant).map { |approval| approval_row(approval) },
          presets: Nibble::Oauth::Consent.new(Nibble::Current.user, device: true).presets,
          areas: Nibble::Oauth::Consent.new(Nibble::Current.user).areas,
          endpoints: { mcp: Nibble::Oauth.resources(request)[:mcp], api: Nibble::Oauth.resources(request)[:api] },
          issued: flash[:issued_token]
        }
      end

      def create
        return redirect_to("/cp/account/apps", alert: "Agent access is turned off on this site.") unless AgentAccess.enabled?
        raise NotAuthorized unless Nibble::Access.can?(Nibble::Current.user, "apps.connect")

        attrs = params.permit(:name, :preset, :expires_in, areas: {})
        abilities = Nibble::Oauth::Consent.new(Nibble::Current.user, device: true).abilities(attrs[:preset], attrs[:areas]&.to_h)
        grant = Nibble::Grant.create!(user: Nibble::Current.user, kind: "ci", name: attrs[:name].to_s.strip.presence || "Script",
          preset: attrs[:preset], abilities:, via: "token", expires_at: EXPIRIES.fetch(attrs[:expires_in].to_s, 30.days).from_now)
        token = Nibble::OauthToken.issue(grant, "ci", resource: Nibble::Oauth.resources(request)[:api], expires_at: grant.expires_at)
        flash[:issued_token] = { name: grant.name, token: }
        redirect_to "/cp/account/apps", notice: "Token created. It's shown only once."
      rescue Nibble::Oauth::Error, ActiveRecord::RecordInvalid => error
        redirect_to "/cp/account/apps", inertia: { errors: { preset: error.message } }
      end

      def update
        Nibble::Oauth::AccessChange.new(grant, by: Nibble::Current.user, ip: request.remote_ip).call(**change_params)
        redirect_to "/cp/account/apps", notice: "Saved. The app has this access from its next request."
      rescue Nibble::Oauth::AccessChange::Refused => refused
        redirect_to "/cp/account/apps", inertia: { errors: { refused.field => refused.message } }
      end

      def destroy
        grant.revoke!
        redirect_to "/cp/account/apps", notice: "Disconnected."
      end

      private

      def grant = Nibble::Current.user.grants.find(params[:id])

      def approval_row(approval)
        { id: approval.public_id, app: approval.grant.name, operation: Nibble::Operations.find(approval.operation)&.title,
          title: approval.preview["title"] || approval.preview["handle"] || approval.preview["filename"], upload: approval.input["upload"],
          created_at: approval.created_at.utc.iso8601 }
      end

      def changes_access? = params.key?(:preset) || params.key?(:areas) || params.key?(:approval_mode)

      def change_params
        params.permit(:name, :preset, :approval_mode, areas: {}).to_h.symbolize_keys
      end

      def row(grant)
        client = grant.oauth_client
        { id: grant.id, kind: grant.kind, host: client&.id_host, verified: client.nil? || client.verified?, created_at: grant.created_at.utc.iso8601,
          **Nibble::Oauth::AccessChange.props(grant) }
      end
    end
  end
end
