module Nibble
  # An analytics card holds its vendor's snippet exactly as the vendor gives it, in a field named for where it goes on
  # the page, so what reaches the page is what the vendor supports, however its snippet changes.
  module Analytics
    PLACES = %w[head body_start body_end].freeze
    TAGS = %w[script noscript].freeze

    module_function

    def html(cards, place)
      Array(cards).filter_map do |card|
        card = card.to_h.stringify_keys
        card[place.to_s].presence if card["enabled"] != false
      end
    end

    # The shape of a snippet, never its content: a vendor's format can change without Nibble refusing it.
    def snippet_problem(text)
      nodes = Nokogiri::HTML5.fragment(text.to_s).children.reject { |node| node.comment? || (node.text? && node.text.strip.empty?) }
      return if nodes.any? && nodes.all? { |node| node.element? && TAGS.include?(node.name) }

      "Paste the snippet exactly as the vendor gives it: <script> tags, and <noscript> if it has one."
    end
  end
end
