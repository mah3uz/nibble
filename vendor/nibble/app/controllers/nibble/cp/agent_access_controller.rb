module Nibble
  module Cp
    class AgentAccessController < BaseController
      before_action { authorize!("agents.manage") }
      before_action :require_elevated_page, only: :show
      before_action :require_elevated_session, except: :show

      def show
        render inertia: "cp/agent_access/Show", props: {
          enabled: AgentAccess.enabled?,
          device_sign_in: AgentAccess.device_sign_in?,
          approvals: AgentAccess.approvals,
          areas: AgentAccess.areas.map { |area| area_row(area) },
          columns: AgentAccess::COLUMNS.map { |value, label| { value:, label: } },
          roles: Nibble::Role.order(:title).select { |role| Nibble::Access.matches?(role.grants, "apps.connect") }.map(&:title),
          grants: Nibble::Grant.active.includes(:user, :oauth_client).order(created_at: :desc).map { |grant| grant_row(grant) },
          endpoints: { mcp: Nibble::Oauth.resources(request)[:mcp], api: Nibble::Oauth.resources(request)[:api] }
        }
      end

      def update
        settings = params.permit(:enabled, :device_sign_in, :approvals, areas: {})
        AgentAccess.update!(enabled: boolean(settings[:enabled]), device_sign_in: boolean(settings[:device_sign_in]), approvals: settings[:approvals],
          areas: settings[:areas]&.to_h&.transform_values { |values| values.to_h.transform_values { |value| value.to_s == "true" } })
        redirect_to "/cp/agent-access", notice: "Agent access saved."
      end

      def change
        grant = Nibble::Grant.find(params[:id])
        Nibble::Oauth::AccessChange.new(grant, by: Nibble::Current.user, ip: request.remote_ip)
          .call(**params.permit(:name, :preset, :approval_mode, areas: {}).to_h.symbolize_keys)
        redirect_to "/cp/agent-access", notice: "Saved. The app has this access from its next request."
      rescue Nibble::Oauth::AccessChange::Refused => refused
        redirect_to "/cp/agent-access", inertia: { errors: { refused.field => refused.message } }
      end

      def revoke
        Nibble::Grant.find(params[:id]).revoke!
        redirect_to "/cp/agent-access", notice: "Disconnected."
      end

      private

      def boolean(value) = value.nil? ? nil : value.to_s == "true"

      def area_row(area)
        { key: area.key, title: area.title, group: area.group, values: area.columns.index_with { |column| AgentAccess.value(area.key, column) } }
      end

      def grant_row(grant)
        { id: grant.id, kind: grant.kind, owner: { id: grant.user.id, name: grant.user.name, email: grant.user.email_address },
          created_at: grant.created_at.utc.iso8601, **Nibble::Oauth::AccessChange.props(grant) }
      end
    end
  end
end
