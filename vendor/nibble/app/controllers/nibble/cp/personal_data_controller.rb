module Nibble
  module Cp
    class PersonalDataController < BaseController
      before_action { raise NotAuthorized unless Nibble::Current.user.admin? }
      before_action :require_elevated_page, only: :show
      before_action :require_elevated_session, except: :show
      before_action :find_person

      def show
        matches = @person.submissions
        titles = Nibble::Forms.all.to_h { |form| [ form.handle, form.title || form.handle.humanize ] }
        forms = matches.group_by(&:form).map { |handle, items| { handle:, title: titles[handle] || handle, removed: !titles.key?(handle), count: items.size } }
        render inertia: "cp/personal_data/Show", props: { email: @person.email, searched: @person.present?, total: matches.size, forms:,
          saved: @person.partials.size }
      end

      def export
        matches = @person.submissions
        partials = @person.partials
        audit("form.person_exported", matches, saved: partials.size)
        stamp = Date.current.iso8601
        if params[:format] == "csv"
          send_data(Nibble::Forms::Person.csv(matches, partials), filename: "personal-data-#{stamp}.csv", type: "text/csv")
        else
          send_data(JSON.pretty_generate(Nibble::Forms::Person.json(matches, partials)), filename: "personal-data-#{stamp}.json", type: "application/json")
        end
      end

      def destroy
        matches = @person.submissions
        partials = @person.partials
        Nibble::Records::FormSubmission.transaction do
          matches.each(&:destroy!)
          partials.each(&:destroy!)
          audit("form.person_erased", matches, saved: partials.size)
        end
        saved = " and #{partials.size} saved #{'form'.pluralize(partials.size)}" if partials.any?
        redirect_to "/cp/personal-data", notice: "#{matches.size} #{'submission'.pluralize(matches.size)}#{saved} erased."
      end

      private

      def find_person = @person = Nibble::Forms::Person.new(params[:email])

      def audit(action, matches, **extra)
        Nibble::Forms::Audit.record(action, user: Nibble::Current.user, ip: request.remote_ip, email_digest: @person.digest,
          count: matches.size, forms: matches.group_by(&:form).transform_values(&:size), **extra)
      end
    end
  end
end
