module Api
  module V1
    class NavigationController < BaseController
      before_action :readable!

      def show
        Nibble.schema.find(:navigation, params[:id]) or raise ActiveRecord::RecordNotFound
        tree = Nibble::Records::NavigationTree.find_by!(handle: params[:id], locale:)

        respond({ "data" => presenter.present_navigation(tree) })
      end
    end
  end
end
