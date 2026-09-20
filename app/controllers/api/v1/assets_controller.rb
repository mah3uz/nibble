module Api
  module V1
    class AssetsController < BaseController
      before_action :readable!

      def show
        asset = Nibble::Records::Asset.where(deleted_at: nil).find_by!(uuid: params[:id])

        respond({ "data" => presenter.present([ asset ]).first })
      end
    end
  end
end
