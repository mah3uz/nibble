module Api
  module V1
    class ChangelogsController < ActionController::API
      # Every Control Plane decides whether to offer an upgrade from this, so it is the feed byte for byte.
      def index
        feed = Nibble.config.content_path.join("changelogs/releases.json")
        return head :not_found unless feed.file?

        response.headers["cache-control"] = "public, max-age=300"
        # A Control Plane from before pages asks without one, and gets the whole feed it expects.
        return render json: feed.read unless params.key?(:page)

        releases = JSON.parse(feed.read)
        per_page = params[:per_page].present? ? params[:per_page].to_i.clamp(1, 50) : 10
        page = [ params[:page].to_i, 1 ].max
        response.headers["x-total-count"] = releases.size.to_s
        response.headers["x-page"] = page.to_s
        response.headers["x-per-page"] = per_page.to_s
        response.headers["x-last-page"] = [ (releases.size / per_page.to_f).ceil, 1 ].max.to_s
        render json: releases.slice((page - 1) * per_page, per_page) || []
      end
    end
  end
end
