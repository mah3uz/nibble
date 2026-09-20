require "commonmarker"

module Nibble
  # Markdown written by people we trust — the docs, release notes, a Markdown field — rendered on the server.
  # It converts and nothing more; sanitising is asked for, because where the text came from decides whether it
  # is needed. See Markdown::Sanitizer.
  module Markdown
    OPTIONS = {
      parse: { smart: true },
      # hardbreaks defaults to on, which turns every wrapped line of a document into a <br>.
      render: { unsafe: false, github_pre_lang: true, hardbreaks: false },
      extension: {
        table: true, strikethrough: true, tasklist: true, autolink: true,
        footnotes: true, header_ids: "", alerts: true, front_matter_delimiter: "---"
      }
    }.freeze

    # Comrak highlights code itself, in inline styles and a theme of its own choosing. A stylesheet does it
    # better: `pre` keeps its language, and a site decides how it looks.
    PLUGINS = { syntax_highlighter: nil }.freeze

    module_function

    def render(text, sanitize: false)
      html = Commonmarker.to_html(text.to_s, options: OPTIONS, plugins: PLUGINS)
      sanitize ? Sanitizer.sanitize(html) : html
    end

    def front_matter(text)
      raw = text.to_s[/\A---\n(.*?)\n---\n/m, 1] or return {}

      YAML.safe_load(raw, permitted_classes: [ Date, Time ]) || {}
    rescue Psych::SyntaxError
      {}
    end
  end
end
