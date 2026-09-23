module Api
  module V1
    class ChangelogsController < ActionController::API
      # Every control panel decides whether to offer an upgrade from this, so it is the feed byte for byte.
      def index
        feed = Nibble.config.content_path.join("changelogs/releases.json")
        return head :not_found unless feed.file?

        response.headers["cache-control"] = "public, max-age=300"
        render json: feed.read
      end
    end
  end
end
