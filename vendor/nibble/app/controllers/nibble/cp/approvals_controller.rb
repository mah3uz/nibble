module Nibble
  module Cp
    class ApprovalsController < BaseController
      BATCH = 50

      before_action :load_approval, except: :batch
      before_action :require_elevated_page, only: :show
      before_action :require_elevated_session, only: %i[update batch]

      def show
        operation = Nibble::Operations.find(@approval.operation)
        render inertia: "cp/approvals/Show", props: {
          id: @approval.public_id, status: @approval.state,
          app: @approval.grant.name, operation: described(operation),
          summary: @approval.preview.slice("title", "status", "url", "collection", "taxonomy", "handle", "filename"),
          changes: changes, input: @approval.input.except("data", "tree", "content_base64"),
          other_sites: other_sites, expires_at: @approval.expires_at.utc.iso8601,
          result: @approval.result&.slice("result", "title", "status", "url", "cp_url", "filename", "handle"),
          error: @approval.failure&.slice("code", "message", "hint")
        }
      end

      def update
        return redirect_to("/cp/approvals/#{@approval.public_id}", alert: "This request was already decided or has expired.") unless @approval.open?

        approval = decide(@approval)
        path = "/cp/approvals/#{approval.public_id}"
        case approval.status
        when "done" then redirect_to path, notice: "Approved and done."
        when "failed" then redirect_to path, alert: "Approved, but the change couldn't be made: #{approval.error['message']}"
        when "denied" then redirect_to path, notice: "Declined."
        else redirect_to path, alert: "This request was already decided or has expired."
        end
      end

      BATCH_WORDS = { "denied" => "declined", "not_found" => "not found" }.freeze

      def batch
        ids = Array(params[:ids]).map(&:to_s).uniq.first(BATCH)
        found = Nibble::Approval.includes(:grant).where(public_id: ids).select { |approval| approval.grant.user_id == Nibble::Current.user.id }.index_by(&:public_id)
        outcomes = ids.map do |id|
          approval = found[id] or next { id:, status: "not_found" }

          approval = decide(approval) if approval.open?
          { id:, status: approval.state, error: approval.failure&.dig("message") }
        end
        return render(json: { approvals: outcomes }) if request.format.json? && !request.inertia?

        counts = outcomes.group_by { |outcome| outcome[:status] }.transform_values(&:size)
        message = counts.map { |status, count| "#{count} #{BATCH_WORDS.fetch(status, status)}" }.join(", ")
        flash_key = counts.keys.intersect?(%w[failed expired not_found]) ? :alert : :notice
        redirect_back_or_to "/cp/account/apps", flash_key => message
      end

      private

      def decide(approval)
        return Nibble::Operations.carry_out(approval, site: Nibble::Oauth.issuer(request), ip: request.remote_ip) if params[:decision] == "approve"

        Nibble::Approval.where(id: approval.id, status: "pending").update_all(status: "denied", decided_at: Time.current, updated_at: Time.current)
        approval.reload
      end

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
