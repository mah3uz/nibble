module Nibble
  module Analytics
    Format = Data.define(:pattern, :name, :example)

    FORMATS = {
      "ga4" => Format.new(/\AG-[A-Z0-9]+\z/, "GA4 measurement ID", "G-XXXXXXXXXX"),
      "gtm" => Format.new(/\AGTM-[A-Z0-9]+\z/, "Tag Manager container ID", "GTM-XXXXXXX"),
      "fathom" => Format.new(/\A[A-Z0-9]+\z/, "Fathom site ID", "ABCDEFGH"),
      "umami" => Format.new(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, "Umami website ID", "94db1cb1-74f4-4a40-ad6c-962362670409"),
      "cloudflare" => Format.new(/\A[A-Za-z0-9]{16,64}\z/, "Cloudflare token", "a string of letters and numbers"),
      "domain" => Format.new(/\A[a-z0-9.-]+(,[a-z0-9.-]+)*\z/, "domain", "example.com"),
      "script_url" => Format.new(%r{\Ahttps://[^\s"'<>\\]+\z}, "script URL", "https://example.com/script.js")
    }.freeze

    PLAUSIBLE_INIT = "<script>window.plausible=window.plausible||function(){(plausible.q=plausible.q||[]).push(arguments)}," \
      "plausible.init=plausible.init||function(i){plausible.o=i||{}};plausible.init()</script>".freeze

    class Page
      PLACES = %i[head body_start body_end].freeze

      attr_reader :tags

      def initialize
        @tags = PLACES.index_with { [] }
        @once = Set.new
      end

      # A loader several cards share, such as gtag.js, is added once under a key.
      def add(place, html, once: nil)
        raise ArgumentError, "unknown place #{place.inspect} (use #{PLACES.join(', ')})" unless PLACES.include?(place)
        return if once && !@once.add?(once)

        @tags[place] << html
      end
    end

    mattr_accessor :renderers, default: {}

    class << self
      def register(handle, &render) = renderers[handle.to_s] = render

      def render(cards)
        Page.new.tap do |page|
          Array(cards).each do |card|
            card = card.to_h.stringify_keys
            next if card["enabled"] == false

            renderers[card["type"].to_s]&.call(card, page)
          end
        end
      end

      def valid?(format, value) = FORMATS.fetch(format).pattern.match?(value.to_s)

      def format_error(format, value)
        found = FORMATS.fetch(format)
        "That isn't a #{found.name}; it looks like #{found.example}." unless found.pattern.match?(value.to_s)
      end

      def h(value) = ERB::Util.html_escape(value)
      def js(value) = ERB::Util.json_escape(value.to_json)

      def plausible_legacy?(src)
        URI.parse(src).path.to_s.split("/").last.to_s.start_with?("script.")
      rescue URI::InvalidURIError
        false
      end
    end

    register("ga4") do |card, page|
      id = card["measurement_id"].to_s
      next unless valid?("ga4", id)

      page.add(:head, %(<script async src="https://www.googletagmanager.com/gtag/js?id=#{ERB::Util.url_encode(id)}"></script>), once: "gtag.js")
      page.add(:head, "<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());</script>", once: "gtag")
      page.add(:head, "<script>gtag('config',#{js(id)});</script>")
    end

    register("gtm") do |card, page|
      id = card["container_id"].to_s
      next unless valid?("gtm", id)

      page.add(:head, "<script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer',#{js(id)});</script>")
      page.add(:body_start, %(<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=#{ERB::Util.url_encode(id)}" height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>))
    end

    register("plausible") do |card, page|
      src = card["script_url"].to_s
      next unless valid?("script_url", src)

      if plausible_legacy?(src)
        domain = card["domain"].to_s
        next unless valid?("domain", domain)

        page.add(:head, %(<script defer data-domain="#{h(domain)}" src="#{h(src)}"></script>))
      else
        page.add(:head, %(<script async src="#{h(src)}"></script>))
        page.add(:head, PLAUSIBLE_INIT, once: "plausible.init")
      end
    end

    register("fathom") do |card, page|
      id = card["site_id"].to_s
      next unless valid?("fathom", id)

      page.add(:head, %(<script src="https://cdn.usefathom.com/script.js" data-site="#{h(id)}" data-spa="auto" defer></script>))
    end

    register("umami") do |card, page|
      id = card["website_id"].to_s
      src = card["script_url"].presence || "https://cloud.umami.is/script.js"
      next unless valid?("umami", id) && valid?("script_url", src)

      page.add(:head, %(<script defer src="#{h(src)}" data-website-id="#{h(id)}"></script>))
    end

    register("cloudflare") do |card, page|
      token = card["token"].to_s
      next unless valid?("cloudflare", token)

      beacon = { token:, spa: true }.to_json
      page.add(:head, %(<script defer src="https://static.cloudflareinsights.com/beacon.min.js" data-cf-beacon="#{h(beacon)}"></script>), once: "cloudflare")
    end

    register("script") do |card, page|
      src = card["script_url"].to_s
      next unless valid?("script_url", src)

      attributes = Array(card["attributes"]).filter_map do |row|
        row = row.to_h.stringify_keys
        %( #{row['name']}="#{h(row['value'])}") if row["name"].to_s.match?(/\Adata-[a-z0-9-]+\z/)
      end
      page.add(:head, %(<script defer src="#{h(src)}"#{attributes.join}></script>))
    end
  end
end
