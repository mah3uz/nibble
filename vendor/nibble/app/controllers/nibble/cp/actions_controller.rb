module Nibble
  module Cp
    class ActionsController < BaseController
      ACTIONS = { "publish" => :publish, "unpublish" => :unpublish, "trash" => :trash, "move" => :move }.freeze

      def run
        return submission_action if params[:resource].to_s.start_with?("forms.")
        return delete_redirects if params[:resource] == "redirects"

        model, item = resource
        action = ACTIONS.fetch(params[:handle]) { params[:handle].to_s.start_with?("assign_") ? :assign_terms : raise(ActiveRecord::RecordNotFound) }
        records = model.kept.where(id: Array(params[:ids])).to_a
        raise NotAuthorized unless records.all? { |record| Nibble::Access.can?(Nibble::Current.user, ability(item, action), record) }

        failures = apply(records, action)
        notice = "#{records.size - failures.size} of #{records.size} #{'item'.pluralize(records.size)} updated."
        redirect_back_or_to cp_root_path, notice: failures.empty? ? notice.sub(/\A\d+ of \d+/, records.size.to_s) : notice,
          alert: failures.presence && failures.first
      end

      private

      SUBMISSION_ACTIONS = {
        "mark_handled" => { handled_at: -> { Time.current }, handled_by_id: -> { Nibble::Current.user.id } },
        "mark_new" => { handled_at: -> { nil }, handled_by_id: -> { nil } },
        "mark_unread" => { read_at: -> { nil } }
      }.freeze

      def submission_action
        form = Nibble::Forms.find(params[:resource].delete_prefix("forms.")) or raise ActiveRecord::RecordNotFound
        records = Nibble::Records::FormSubmission.where(form: form.handle, id: Array(params[:ids])).to_a
        return delete_submissions(form, records) if params[:handle] == "delete"

        changes = SUBMISSION_ACTIONS.fetch(params[:handle]) { raise ActiveRecord::RecordNotFound }
        authorize!("forms.#{form.handle}.edit")
        Nibble::Records::FormSubmission.where(id: records.map(&:id)).update_all(changes.transform_values(&:call).merge(updated_at: Time.current))
        redirect_back_or_to "/cp/forms/#{form.handle}", notice: "#{records.size} #{'submission'.pluralize(records.size)} updated."
      end

      def delete_submissions(form, records)
        authorize!("forms.#{form.handle}.delete")
        records.each(&:destroy!)
        Nibble::Forms::Audit.record("form.submission_deleted", user: Nibble::Current.user, ip: request.remote_ip, form: form.handle, count: records.size)
        redirect_back_or_to "/cp/forms/#{form.handle}", notice: "#{records.size} #{'submission'.pluralize(records.size)} deleted."
      end

      def delete_redirects
        raise ActiveRecord::RecordNotFound unless params[:handle] == "delete"

        authorize!("redirects.manage")
        count = Nibble::Records::Redirect.where(id: Array(params[:ids])).destroy_all.size
        redirect_back_or_to cp_redirects_path, notice: "#{count} #{'redirect'.pluralize(count)} deleted."
      end

      def apply(records, action)
        failures = []
        model_for(records).transaction do
          records.each do |record|
            result = Nibble::Lifecycle.call(record, action, attrs_for(action), actor: Nibble::Current.user)
            failures << "#{record.title}: #{result.errors.values.flatten.first}" unless result.ok?
          end
        end
        failures
      end

      def attrs_for(action)
        case action
        when :trash then { "force" => true }
        when :move
          parent = params.dig(:values, :parent_id).to_s
          raise ActionController::BadRequest, "choose where to move them" if parent.blank?

          { "parent_id" => parent == Nibble::Cp::Listing::TOP_LEVEL ? nil : parent }
        when :assign_terms
          term = params.dig(:values, :term_ids).to_s
          raise ActionController::BadRequest, "choose a term" if term.blank?

          { "field" => params[:handle].delete_prefix("assign_"), "term_ids" => [ term ] }
        else {}
        end
      end

      def model_for(records) = records.first&.class || Nibble::Records::Entry

      def resource
        kind, handle = params.require(:resource).split(".", 2)
        case kind
        when "collections" then [ Nibble::Records::Entry.where(collection: handle), Nibble.schema.collection(handle) ]
        when "taxonomies" then [ Nibble::Records::Term.where(taxonomy: handle), Nibble.schema.taxonomy(handle) ]
        else raise ActiveRecord::RecordNotFound
        end.tap { |_, item| raise ActiveRecord::RecordNotFound unless item }
      end

      def ability(item, action)
        prefix = item.kind == "collections" ? "entries" : "terms"
        suffix = { trash: "delete", move: "edit", assign_terms: "edit" }.fetch(action, "publish")
        "#{prefix}.#{item.handle}.#{suffix}"
      end
    end
  end
end
