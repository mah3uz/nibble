module Admin
  class ActionsController < BaseController
    ACTIONS = { "publish" => :publish, "unpublish" => :unpublish, "trash" => :trash, "move" => :move }.freeze

    def run
      return delete_submissions if params[:resource].to_s.start_with?("forms.")

      model, item = resource
      action = ACTIONS.fetch(params[:handle]) { params[:handle].to_s.start_with?("assign_") ? :assign_terms : raise(ActiveRecord::RecordNotFound) }
      records = model.kept.where(id: Array(params[:ids])).to_a
      raise NotAuthorized unless records.all? { |record| Nibble::Access.can?(Current.user, ability(item, action), record) }

      failures = apply(records, action)
      notice = "#{records.size - failures.size} of #{records.size} #{'item'.pluralize(records.size)} updated."
      redirect_back_or_to admin_root_path, notice: failures.empty? ? notice.sub(/\A\d+ of \d+/, records.size.to_s) : notice,
        alert: failures.presence && failures.first
    end

    private

    def delete_submissions
      raise ActiveRecord::RecordNotFound unless params[:handle] == "delete"

      form = Nibble::Forms.find(params[:resource].delete_prefix("forms.")) or raise ActiveRecord::RecordNotFound
      authorize!("forms.#{form.handle}.delete")
      records = Nibble::Records::FormSubmission.where(form: form.handle, id: Array(params[:ids])).to_a
      records.each(&:destroy!)
      redirect_back_or_to "/admin/forms/#{form.handle}", notice: "#{records.size} #{'submission'.pluralize(records.size)} deleted."
    end

    def apply(records, action)
      failures = []
      model_for(records).transaction do
        records.each do |record|
          result = Nibble::Lifecycle.call(record, action, attrs_for(action), actor: Current.user)
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
