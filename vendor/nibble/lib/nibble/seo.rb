module Nibble
  class Seo
    def self.indexable? = Rails.env.production? && ENV["NIBBLE_BLOCK_INDEXING"].blank?

    def initialize(page:, site:, kind:, url:)
      @page = page.to_h
      @values = @page["seo"].to_h
      @globals = site.dig("globals", "seo").to_h
      @site_name = site.dig("globals", "site", "name").presence
      @favicon = site.dig("globals", "site", "favicon")
      @kind = kind
      @url = url
    end

    def to_h
      {
        "title" => title, "description" => description, "canonical" => canonical, "robots" => robots,
        "image" => image, "site_name" => @site_name, "favicon" => favicon,
        "og_type" => article? ? "article" : "website",
        "verification" => Array(@globals["verification_tags"]).filter_map { |tag| tag.slice("name", "content") if tag["name"].present? },
        "json_ld" => json_ld
      }
    end

    private

    def favicon
      icon = Array.wrap(@favicon).first
      icon.is_a?(Hash) && icon["url"].present? ? { "href" => icon["url"], "type" => icon["mime"] } : nil
    end

    def image
      value = @values["og_image"].presence
      return value.start_with?("/") ? Presenter.url(value) : value if value

      picked = [ @page["featured_image"], @globals["default_share_image"] ].find { |item| item.is_a?(Hash) && item["id"] }
      asset = picked && Records::Asset.kept.find_by(id: picked["id"]) or return nil
      Presenter.url(asset.url(Assets.preset("og") && Assets.transformable?(asset) ? "og" : nil))
    end

    def title
      base = @values["title"].presence || @page["title"].to_s
      template = @globals["title_template"].presence || "{title} · {site_name}"
      return base unless @site_name

      template.gsub("{title}", base).gsub("{site_name}", @site_name)
    end

    def description
      [ @values["description"], (@page["excerpt"] if @page["excerpt"].is_a?(String)), @globals["default_description"] ].find(&:present?)
    end

    def canonical
      value = @values["canonical"].presence or return @page["url"] || @url
      value.start_with?("/") ? Presenter.url(value) : value
    end

    def robots = @values["noindex"] || @kind == :error || !self.class.indexable? ? "noindex, nofollow" : nil

    def article? = @page["collection"] == "posts" || @values["schema_type"].in?(%w[Article BlogPosting])

    def json_ld
      return [] if @kind == :error

      type = @values["schema_type"].presence || (article? ? "BlogPosting" : "WebPage")
      node = { "@context" => "https://schema.org", "@type" => type, (article? ? "headline" : "name") => @values["title"].presence || @page["title"], "url" => canonical }
      node["datePublished"] = @page["published_at"] if article? && @page["published_at"]
      node["dateModified"] = @page["updated_at"] if @page["updated_at"]
      node["description"] = description if description
      nodes = [ node.merge(@values["json_ld_overrides"].to_h) ]
      if @page["uri"] == "/" && (@globals["organization_name"].presence || @site_name)
        nodes << { "@context" => "https://schema.org", "@type" => "Organization", "name" => @globals["organization_name"].presence || @site_name, "url" => Presenter.url("/") }
      end
      nodes
    end
  end
end
