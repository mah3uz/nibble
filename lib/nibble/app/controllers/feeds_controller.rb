class FeedsController < ActionController::Base
  def index
    return head(:not_found) unless Nibble::Feeds.any?

    expires_in 1.hour, public: true
    render xml: Nibble::Feeds.site_xml
  end

  def show
    source = Nibble::Feeds.find(params[:handle]) or return head(:not_found)

    expires_in 1.hour, public: true
    render xml: Nibble::Feeds.feed_xml(source)
  end
end
