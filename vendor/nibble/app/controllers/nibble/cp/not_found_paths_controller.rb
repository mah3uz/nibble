module Nibble
  module Cp
    class NotFoundPathsController < BaseController
      before_action { authorize!("redirects.manage") }

      def index
        listing = Nibble::Cp::NotFoundListing.new(user: Nibble::Current.user, params:)
        render inertia: "cp/not_found/Index", props: { listing: listing.props, empty: !listing.any? }
      end

      def destroy
        Nibble::Records::NotFound.find(params[:id]).destroy!
        redirect_to cp_not_found_paths_path, notice: "Removed from missing pages."
      end
    end
  end
end
