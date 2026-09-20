module RichText
  class Renderer
    include ERB::Util

    HEADING_LEVELS = (2..4)

    def self.call(document, image_preset: nil)
      Sanitizer.sanitize(new(image_preset:).render(document))
    end

    def initialize(image_preset: nil)
      @image_preset = image_preset
    end

    def render(document)
      node = document.is_a?(String) ? JSON.parse(document) : document
      return "" unless node.is_a?(Hash) && node["type"] == "doc"

      children(node)
    end

    private

    def children(node)
      Array(node["content"]).map { |child| render_node(child) }.join
    end

    def render_node(node)
      return "" unless node.is_a?(Hash)

      attrs = node["attrs"].is_a?(Hash) ? node["attrs"] : {}
      case node["type"]
      when "text" then render_text(node)
      when "paragraph" then "<p>#{children(node)}</p>"
      when "heading"
        level = attrs["level"].to_i.clamp(HEADING_LEVELS.min, HEADING_LEVELS.max)
        "<h#{level}>#{children(node)}</h#{level}>"
      when "bulletList" then "<ul>#{children(node)}</ul>"
      when "orderedList"
        start = attrs["start"].to_i
        start > 1 ? %(<ol start="#{start}">#{children(node)}</ol>) : "<ol>#{children(node)}</ol>"
      when "listItem" then "<li>#{children(node)}</li>"
      when "blockquote" then "<blockquote>#{children(node)}</blockquote>"
      when "codeBlock"
        language = attrs["language"].to_s[/\A[a-z0-9_+-]+\z/i]
        code_class = language ? %( class="language-#{language}") : ""
        "<pre><code#{code_class}>#{html_escape(plain_text(node))}</code></pre>"
      when "hardBreak" then "<br>"
      when "horizontalRule" then "<hr>"
      when "image" then render_image(attrs)
      when "table" then render_table(node)
      when "tableRow" then "<tr>#{children(node)}</tr>"
      when "tableHeader", "tableCell" then render_cell(node, attrs)
      else ""
      end
    end

    def render_text(node)
      Array(node["marks"]).reverse.reduce(html_escape(node["text"].to_s)) do |html, mark|
        next html unless mark.is_a?(Hash)

        case mark["type"]
        when "bold" then "<strong>#{html}</strong>"
        when "italic" then "<em>#{html}</em>"
        when "underline" then "<u>#{html}</u>"
        when "strike" then "<s>#{html}</s>"
        when "code" then "<code>#{html}</code>"
        when "link" then render_link(html, mark["attrs"].is_a?(Hash) ? mark["attrs"] : {})
        else html
        end
      end
    end

    def render_link(html, attrs)
      target = attrs["target"] == "_blank" ? %( target="_blank") : ""
      %(<a href="#{html_escape(attrs['href'])}"#{target}>#{html}</a>)
    end

    def render_image(attrs)
      image = Nibble::Resolvers.find("asset").find([ attrs["asset"].to_s ], scope: { "preset" => @image_preset }).first if attrs["asset"].present?
      return render_asset_image(image, attrs) if image

      parts = [ %(src="#{html_escape(attrs['src'])}"), %(alt="#{html_escape(attrs['alt'])}") ]
      parts << %(title="#{html_escape(attrs['title'])}") if attrs["title"].present?
      %w[width height].each { |dim| parts << %(#{dim}="#{attrs[dim].to_i}") if attrs[dim].to_i.positive? }
      "<img #{parts.join(' ')}>"
    end

    def render_asset_image(image, attrs)
      parts = [ %(src="#{html_escape(image['url'])}"), %(alt="#{html_escape(attrs['alt'].presence || image['alt'])}"), %(loading="lazy"), %(decoding="async") ]
      parts << %(srcset="#{html_escape(image['srcset'])}") if image["srcset"]
      %w[width height].each { |dim| parts << %(#{dim}="#{image[dim]}") if image[dim] }
      parts << %(title="#{html_escape(attrs['title'])}") if attrs["title"].present?
      "<img #{parts.join(' ')}>"
    end

    def render_table(node)
      rows = Array(node["content"])
      header = rows.first if rows.first && Array(rows.first["content"]).all? { |cell| cell["type"] == "tableHeader" }
      body = header ? rows.drop(1) : rows
      thead = header ? "<thead>#{render_node(header)}</thead>" : ""
      "<table>#{colgroup(rows.first)}#{thead}<tbody>#{body.map { |row| render_node(row) }.join}</tbody></table>"
    end

    def colgroup(row)
      widths = Array(row&.[]("content")).flat_map { |cell| Array(cell.dig("attrs", "colwidth")).presence || [ nil ] }
      return "" if widths.compact.empty?

      "<colgroup>#{widths.map { |width| width.to_i.positive? ? %(<col width="#{width.to_i}">) : "<col>" }.join}</colgroup>"
    end

    def render_cell(node, attrs)
      tag = node["type"] == "tableHeader" ? "th" : "td"
      spans = %w[colspan rowspan].filter_map { |span| %( #{span}="#{attrs[span].to_i}") if attrs[span].to_i > 1 }.join
      # Tiptap puts a paragraph in every cell; a lone one renders bare so prose margins don't pad the row.
      content = Array(node["content"])
      inner = content.size == 1 && content.first["type"] == "paragraph" ? children(content.first) : children(node)
      "<#{tag}#{spans}>#{inner}</#{tag}>"
    end

    def plain_text(node)
      node["type"] == "text" ? node["text"].to_s : Array(node["content"]).map { |child| plain_text(child) }.join
    end
  end
end
