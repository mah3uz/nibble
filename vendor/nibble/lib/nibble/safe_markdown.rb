module Nibble
  # Markdown for short copy a form shows: links that pass SafeUrl and plain formatting, and nothing else becomes HTML.
  module SafeMarkdown
    BLOCK_TAGS = %w[p br ul ol li strong em a].freeze
    LABEL_TAGS = %w[a].freeze

    module_function

    def link?(text) = text.is_a?(String) && text.include?("](")

    def html(text) = clean(text, BLOCK_TAGS)

    def label_html(text) = clean(text, LABEL_TAGS).strip.presence

    def label_text(text) = Markdown.text(text) || text.to_s

    def clean(text, tags)
      rendered = Commonmarker.to_html(text.to_s, options: { render: { unsafe: false } })
      fragment = Nokogiri::HTML5.fragment(Rails::HTML5::SafeListSanitizer.new.sanitize(rendered, tags:, attributes: %w[href]))
      fragment.css("a").each do |link|
        next link.replace(link.children) unless SafeUrl.safe?(link["href"]) && link["href"].strip.match?(RichText::Sanitizer::SAFE_URL)

        link["rel"] = "noopener"
      end
      fragment.to_html
    end
  end
end
