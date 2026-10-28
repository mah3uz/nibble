module Nibble
  module Cp
    class TrashController < BaseController
      def index
        authorize!("trash.view")
        listing = Nibble::Cp::TrashListing.new(user: Nibble::Current.user, params:)
        render inertia: "cp/trash/Index", props: { listing: listing.props, empty: listing.empty? }
      end

      def restore
        record = find_record
        authorize!(ability(record, "delete"), record)
        result = Nibble::Lifecycle.call(record, :restore, {}, actor: Nibble::Current.user)
        return redirect_to(cp_trash_index_path, alert: result.errors.values.flatten.first) unless result.ok?

        redirect_to cp_trash_index_path, notice: "Restored."
      end

      def purge
        record = find_record
        authorize!(ability(record, "delete"), record)
        Nibble::Records::Relation.where(target_type: record.record_type, target_id: record.id).delete_all
        record.destroy!
        redirect_to cp_trash_index_path, notice: "Deleted for good."
      end

      private

      def find_record
        type, id = params[:id].split("-", 2)
        Nibble::Records.model(type).find(id)
      end

      def ability(record, action)
        case record
        when Nibble::Records::Entry then "entries.#{record.collection}.#{action}"
        when Nibble::Records::Term then "terms.#{record.taxonomy}.#{action}"
        else "assets.#{action}"
        end
      end
    end
  end
end
