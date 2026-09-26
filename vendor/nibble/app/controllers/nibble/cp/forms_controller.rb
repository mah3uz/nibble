module Nibble
  module Cp
    class FormsController < BaseController
      def index
        counts = Nibble::Records::FormSubmission.kept.group(:form).count
        unread = Nibble::Records::FormSubmission.kept.unread.group(:form).count
        visible = Nibble::Forms.all.select { |form| can_view?(form) }
        raise NotAuthorized if visible.empty? && Nibble::Forms.all.any?

        forms = visible.map do |form|
          { handle: form.handle, title: form.title || form.handle.humanize, submissions: counts.fetch(form.handle, 0),
            unread: unread.fetch(form.handle, 0), store: form.store?, url: "/cp/forms/#{form.handle}" }
        end
        render inertia: "cp/forms/Index", props: { forms: forms.sort_by { |form| form[:title].downcase } }
      end

      def show
        form = find_form
        authorize!("forms.#{form.handle}.view")
        listing = Nibble::Cp::SubmissionListing.new(form, user: Nibble::Current.user, params:)
        if request.format.csv?
          authorize!("forms.#{form.handle}.export")
          return send_data(listing.to_csv, filename: "#{form.handle}-submissions-#{Date.current.iso8601}.csv", type: "text/csv")
        end

        render inertia: "cp/forms/Show", props: {
          form: { handle: form.handle, title: form.title || form.handle.humanize, store: form.store?,
                  can_export: Nibble::Access.can?(Nibble::Current.user, "forms.#{form.handle}.export") },
          listing: listing.props
        }
      end

      private

      def find_form = Nibble::Forms.find(params[:handle]) || raise(ActiveRecord::RecordNotFound)

      def can_view?(form) = Nibble::Access.can?(Nibble::Current.user, "forms.#{form.handle}.view")
    end
  end
end
