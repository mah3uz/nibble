module RichText
  module Sanitizer
    TAGS = %w[
      p br hr h2 h3 h4 strong em u s code pre blockquote ul ol li a img
      table colgroup col thead tbody tr th td
    ].freeze
    ATTRIBUTES = %w[href target rel src srcset sizes loading decoding alt title width height start colspan rowspan class].freeze
    URL_ATTRIBUTES = %w[href src].freeze
    SAFE_URL = %r{\A(?:https?://|mailto:|tel:|/(?!/)|#)}i

    module_function

    def sanitize(html)
      fragment = Rails::HTML5::SafeListSanitizer.new.sanitize(html.to_s, tags: TAGS, attributes: ATTRIBUTES)
      enforce_url_allowlist(fragment)
    end

    # Belt and braces on top of the sanitizer's own protocol check.
    def enforce_url_allowlist(html)
      doc = Nokogiri::HTML5.fragment(html)
      doc.css("[href], [src], [srcset]").each do |node|
        URL_ATTRIBUTES.each do |attr|
          next unless node[attr]

          node.remove_attribute(attr) unless node[attr].strip.match?(SAFE_URL)
        end
        if node["srcset"] && !node["srcset"].split(",").all? { |candidate| candidate.strip.split(/\s+/).first.to_s.match?(SAFE_URL) }
          node.remove_attribute("srcset")
        end
        node["rel"] = "noopener noreferrer" if node.name == "a" && node["target"] == "_blank"
      end
      doc.to_html
    end
  end
end
