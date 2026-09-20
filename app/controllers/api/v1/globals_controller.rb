module Api
  module V1
    class GlobalsController < BaseController
      before_action :readable!

      def show
        raise ActiveRecord::RecordNotFound if params[:id] == Nibble::Integrations::HANDLE

        set = Nibble.schema.find(:globals, params[:id]) or raise ActiveRecord::RecordNotFound
        global = Nibble::Records::GlobalSet.find_by!(handle: set.handle, locale:)

        respond({ "data" => presenter.present_global(global) })
      end
    end
  end
end
