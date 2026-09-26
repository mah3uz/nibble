module Nibble
  module Cp
    class NotFoundPathsController < BaseController
      before_action { authorize!("redirects.manage") }

      def index
        render inertia: "cp/not_found/Index", props: {
          paths: Nibble::Records::NotFound.order(hits: :desc).limit(100).map do |row|
            { id: row.id, path: row.path, hits: row.hits, referrer: row.referrer,
              first_seen_at: row.first_seen_at.utc.iso8601, last_seen_at: row.last_seen_at.utc.iso8601 }
          end
        }
      end

      def destroy
        Nibble::Records::NotFound.find(params[:id]).destroy!
        redirect_to cp_not_found_paths_path, notice: "Removed from the 404 log."
      end
    end
  end
end
