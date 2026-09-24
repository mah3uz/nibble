require "commonmarker"

module Nibble
  module Markdown
    OPTIONS = {
      parse: { smart: true },
      # Comrak wraps every line by default, and puts the language on the <pre>; highlighters read the <code>.
      render: { unsafe: false, github_pre_lang: false, hardbreaks: false },
      extension: {
        table: true, strikethrough: true, tasklist: true, autolink: true,
        footnotes: true, header_ids: "", alerts: true, front_matter_delimiter: "---"
      }
    }.freeze

    # Comrak's own highlighter writes inline styles; a theme highlights from the language class instead.
    PLUGINS = { syntax_highlighter: nil }.freeze

    module_function

    def render(text, sanitize: false)
      html = Commonmarker.to_html(text.to_s, options: OPTIONS, plugins: PLUGINS)
      sanitize ? Sanitizer.sanitize(html) : html
    end

    def text(markdown) = Nokogiri::HTML5.fragment(render(markdown)).text.squish.presence

    def front_matter(text)
      raw = text.to_s[/\A---\n(.*?)\n---\n/m, 1] or return {}

      YAML.safe_load(raw, permitted_classes: [ Date, Time ]) || {}
    rescue Psych::SyntaxError
      {}
    end
  end
end
