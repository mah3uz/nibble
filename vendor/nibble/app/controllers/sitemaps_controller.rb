class SitemapsController < ActionController::Base
  def index
    expires_in 1.hour, public: true
    render xml: Nibble::Sitemaps.index_xml
  end

  def show
    source = Nibble::Sitemaps.find(params[:handle]) or return head(:not_found)

    expires_in 1.hour, public: true
    render xml: Nibble::Sitemaps.urlset_xml(source)
  end

  def robots
    expires_in 1.hour, public: true
    render plain: Nibble::Sitemaps.robots_txt
  end
end
