module Api
  module V1
    class EntriesController < BaseController
      before_action :readable!

      def index
        collection!(params[:collection_handle])
        query("entries:#{params[:collection_handle]}")
      end

      def show
        entry = Nibble::Records::Entry.where(deleted_at: nil).find_by!(uuid: params[:id])
        collection!(entry.collection)
        raise ActiveRecord::RecordNotFound unless preview? || entry.status == "published"

        respond({ "data" => presenter.present([ entry ], include: list(:include).to_a, fields: list(:fields)).first })
      end
    end
  end
end
