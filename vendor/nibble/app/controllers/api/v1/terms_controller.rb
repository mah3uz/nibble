module Api
  module V1
    class TermsController < BaseController
      before_action :readable!

      def index
        taxonomy!(params[:taxonomy_handle])
        query("terms:#{params[:taxonomy_handle]}")
      end

      def show
        term = Nibble::Records::Term.where(deleted_at: nil).find_by!(uuid: params[:id])
        taxonomy!(term.taxonomy)

        respond({ "data" => presenter.present([ term ], include: list(:include).to_a, fields: list(:fields)).first })
      end
    end
  end
end
