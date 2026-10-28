module Nibble
  module Cp
    class RedirectsController < BaseController
      before_action { authorize!("redirects.manage") }

      def index
        render inertia: "cp/redirects/Index", props: {
          listing: Nibble::Cp::RedirectListing.new(user: Nibble::Current.user, params:).props,
          statuses: Nibble::Records::Redirect::STATUSES.map { |status| { value: status, label: Nibble::Cp::RedirectListing.status_label(status) } }
        }
      end

      def create = save(Nibble::Records::Redirect.new(source: "manual"), "Redirect created.")
      def update = save(Nibble::Records::Redirect.find(params[:id]), "Redirect updated.")

      def destroy
        Nibble::Records::Redirect.find(params[:id]).destroy!
        redirect_back_or_to cp_redirects_path, notice: "Redirect deleted."
      end

      private

      def save(redirect, notice)
        redirect.assign_attributes(params.require(:redirect).permit(:from, :to, :status))
        return redirect_back_or_to(cp_redirects_path, inertia: { errors: redirect.errors.to_hash(true).transform_values(&:first) }) unless redirect.save

        redirect_back_or_to cp_redirects_path, notice:
      end
    end
  end
end
