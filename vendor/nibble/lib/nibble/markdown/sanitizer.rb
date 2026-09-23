module Nibble
  module Markdown
    # RichText::Sanitizer is for what the editor produces, and allows none of this: no h1, no del, no task list
    # inputs, no alerts, no footnotes, no heading ids. Markdown needs its own list rather than a wider shared one.
    module Sanitizer
      TAGS = (RichText::Sanitizer::TAGS + %w[h1 h5 h6 del input section sup sub div]).uniq.freeze
      ATTRIBUTES = (RichText::Sanitizer::ATTRIBUTES + %w[id lang type checked disabled aria-label]).uniq.freeze

      module_function

      def sanitize(html)
        fragment = Rails::HTML5::SafeListSanitizer.new.sanitize(html.to_s, tags: TAGS, attributes: ATTRIBUTES)
        RichText::Sanitizer.enforce_url_allowlist(fragment)
      end
    end
  end
end
