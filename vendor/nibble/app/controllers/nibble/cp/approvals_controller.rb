module Nibble
  module Cp
    class ApprovalsController < BaseController
      before_action :load_approval
      before_action :require_elevated_page, only: :show
      before_action :require_elevated_session, only: :update

      def show
        operation = Nibble::Operations.find(@approval.operation)
        render inertia: "cp/approvals/Show", props: {
          id: @approval.public_id, status: @approval.expired? && @approval.status == "pending" ? "expired" : @approval.status,
          app: @approval.grant.name, operation: described(operation),
          summary: @approval.preview.slice("title", "status", "url", "collection", "taxonomy", "handle", "filename"),
          changes: changes, input: @approval.input.except("data", "tree", "content_base64"),
          other_sites: other_sites, expires_at: @approval.expires_at.utc.iso8601
        }
      end

      def update
        return redirect_to("/cp/approvals/#{@approval.public_id}", alert: "This request was already decided or has expired.") unless @approval.open?

        approved = params[:decision] == "approve"
        @approval.update!(status: approved ? "approved" : "denied", decided_at: Time.current)
        redirect_to "/cp/approvals/#{@approval.public_id}", notice: approved ? "Approved. Tell #{@approval.grant.name} to carry on." : "Declined."
      end

      private

      def load_approval
        @approval = Nibble::Approval.includes(:grant).find_by!(public_id: params[:id])
        raise ActiveRecord::RecordNotFound unless @approval.grant.user_id == Nibble::Current.user.id
      end

      def described(operation)
        action = @approval.input["action"].to_s
        return { title: operation&.title, description: operation&.description } if action.empty?

        record = @approval.operation.delete_prefix("transition_")
        { title: "#{action.humanize} #{record == 'entry' ? 'an entry' : "a #{record}"}", description: Nibble::Operations::Entries::TRANSITIONS[action] }
      end

      def changes
        after = @approval.preview["data"] || (@approval.preview.key?("tree") ? { "tree" => @approval.preview["tree"] } : {})
        before = current.to_h
        (after.keys | before.keys).filter_map do |key|
          next if before[key] == after[key]

          { field: key, before: before[key], after: after[key] }
        end
      end

      def current
        input = @approval.input
        case @approval.operation
        when "transition_entry", "update_entry" then entry(input["id"])
        when "update_term", "transition_term" then (term = Nibble::Records::Term.find_by(id: input["id"])) && Nibble::Operations::Editable.term(term, site: "")["data"]
        when "update_global" then Nibble::Records::GlobalSet.find_by(handle: input["handle"], locale: input["locale"] || Nibble.config.default_locale.code)&.values
        when "update_navigation" then { "tree" => Nibble::Records::NavigationTree.find_by(handle: input["handle"], locale: input["locale"] || Nibble.config.default_locale.code)&.tree }
        end
      end

      def entry(id)
        record = Nibble::Records::Entry.find_by(id:) or return nil

        record.live? ? Nibble::Operations::Editable.outgoing(record.blueprint_fields, record.snapshot) : Nibble::Operations::Editable.entry(record, site: "")["data"]
      end

      def other_sites
        own = URI.parse(Nibble::Oauth.issuer(request)).host
        @approval.input.to_json.scan(%r{https?://[^\s"'<>)\]]+}).filter_map { |url| URI.parse(url).host rescue nil }.uniq - [ own ]
      end
    end
  end
end
