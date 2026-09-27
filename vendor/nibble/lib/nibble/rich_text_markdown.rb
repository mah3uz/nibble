module Nibble
  # Rich text as Markdown for apps and the CLI, which write it far more reliably than editor JSON.
  module RichTextMarkdown
    OPTIONS = { extension: { table: true, strikethrough: true, autolink: true } }.freeze
    ASSET = /\Aasset:(\d+)\z/
    BLOCKS = %w[paragraph heading bulletList orderedList listItem blockquote codeBlock horizontalRule image table tableRow
                tableHeader tableCell].freeze
    INLINE = %w[text hardBreak].freeze
    MARKS = %w[bold italic strike code link].freeze

    module_function

    def to_nodes(markdown)
      document = Commonmarker.parse(markdown.to_s, options: OPTIONS)
      document.map { |node| block(node) }.flatten.compact
    end

    def to_markdown(nodes)
      nodes = Array(nodes)
      return nil unless representable?(nodes)

      nodes.map { |node| markdown_block(node) }.join("\n\n")
    end

    def representable?(nodes)
      Array(nodes).all? do |node|
        next false unless node.is_a?(Hash) && (BLOCKS + INLINE).include?(node["type"])
        next false if Array(node["marks"]).any? { |mark| !MARKS.include?(mark["type"]) }

        representable?(node["content"])
      end
    end

    def block(node)
      case node.type
      when :paragraph
        content = inline(node)
        images, rest = content.partition { |child| child["type"] == "image" }
        return images if rest.empty?

        wrap("paragraph", rest)
      when :heading then wrap("heading", inline(node), "level" => node.header_level.clamp(1, 6))
      when :list
        type = node.list_type == :ordered ? "orderedList" : "bulletList"
        attrs = type == "orderedList" && node.list_start.to_i > 1 ? { "start" => node.list_start } : nil
        wrap(type, node.map { |item| wrap("listItem", item.map { |child| block(child) }.flatten.compact) }, attrs)
      when :block_quote then wrap("blockquote", node.map { |child| block(child) }.flatten.compact)
      when :code_block
        attrs = node.fence_info.to_s[/\A[a-z0-9_+-]+/i]&.then { |language| { "language" => language } }
        wrap("codeBlock", [ text(node.string_content.chomp) ], attrs)
      when :thematic_break then { "type" => "horizontalRule" }
      when :table then table(node)
      when :html_block then wrap("paragraph", [ text(node.to_commonmark.strip) ].compact)
      end
    end

    def table(node)
      rows = node.each_with_index.map do |row, index|
        cell_type = index.zero? ? "tableHeader" : "tableCell"
        wrap("tableRow", row.map { |cell| wrap(cell_type, [ wrap("paragraph", inline(cell)) ]) })
      end
      wrap("table", rows)
    end

    def inline(node, marks = [])
      node.flat_map do |child|
        case child.type
        when :text then [ text(child.string_content, marks) ]
        when :softbreak then [ text(" ", marks) ]
        when :linebreak then [ { "type" => "hardBreak" } ]
        when :code then [ text(child.string_content, marks + [ { "type" => "code" } ]) ]
        when :emph then inline(child, marks + [ { "type" => "italic" } ])
        when :strong then inline(child, marks + [ { "type" => "bold" } ])
        when :strikethrough then inline(child, marks + [ { "type" => "strike" } ])
        when :link
          href = child.url.to_s
          SafeUrl.safe?(href) ? inline(child, marks + [ { "type" => "link", "attrs" => { "href" => href } } ]) : inline(child, marks)
        when :image then image(child)
        when :html_inline then []
        else inline(child, marks)
        end
      end.compact.then { |nodes| merge_text(nodes) }
    end

    def image(node)
      asset = node.url.to_s[ASSET, 1] or return []

      alt = inline(node).filter_map { |child| child["text"] }.join
      [ { "type" => "image", "attrs" => { "asset" => asset, "alt" => alt.presence }.compact } ]
    end

    def text(value, marks = [])
      return nil if value.to_s.empty?

      { "type" => "text", "text" => value.to_s, "marks" => marks.presence }.compact
    end

    def wrap(type, content, attrs = nil)
      { "type" => type, "attrs" => attrs, "content" => content.presence }.compact
    end

    def merge_text(nodes)
      nodes.each_with_object([]) do |node, merged|
        previous = merged.last
        if previous && previous["type"] == "text" && node["type"] == "text" && previous["marks"] == node["marks"]
          previous["text"] += node["text"]
        else
          merged << node.dup
        end
      end
    end

    def markdown_block(node, depth = 0)
      attrs = node["attrs"].to_h
      case node["type"]
      when "paragraph" then markdown_inline(node["content"])
      when "heading" then "#{'#' * attrs['level'].to_i.clamp(1, 6)} #{markdown_inline(node['content'])}"
      when "bulletList", "orderedList" then list(node, depth)
      when "blockquote" then Array(node["content"]).map { |child| markdown_block(child) }.join("\n\n").gsub(/^/, "> ")
      when "codeBlock" then "```#{attrs['language']}\n#{Array(node['content']).map { |child| child['text'] }.join}\n```"
      when "horizontalRule" then "---"
      when "image" then "![#{attrs['alt']}](asset:#{attrs['asset']})"
      when "table" then markdown_table(node)
      else markdown_inline([ node ])
      end
    end

    def list(node, depth)
      start = node.dig("attrs", "start").to_i.nonzero? || 1
      Array(node["content"]).each_with_index.map do |item, index|
        bullet = node["type"] == "orderedList" ? "#{start + index}." : "-"
        blocks = Array(item["content"])
        first = blocks.first ? markdown_block(blocks.first, depth + 1) : ""
        rest = blocks.drop(1).map { |child| markdown_block(child, depth + 1).gsub(/^/, "   ") }
        ([ "#{bullet} #{first}" ] + rest).join("\n")
      end.join("\n")
    end

    def markdown_table(node)
      rows = Array(node["content"]).map do |row|
        Array(row["content"]).map { |cell| Array(cell["content"]).map { |child| markdown_inline(child["content"]) }.join(" ").gsub("|", "\\|") }
      end
      return "" if rows.empty?

      header = "| #{rows.first.join(' | ')} |"
      divider = "| #{rows.first.map { '---' }.join(' | ')} |"
      ([ header, divider ] + rows.drop(1).map { |cells| "| #{cells.join(' | ')} |" }).join("\n")
    end

    def markdown_inline(nodes)
      Array(nodes).map do |node|
        next "  \n" if node["type"] == "hardBreak"
        next markdown_block(node) if node["type"] == "image"

        Array(node["marks"]).reverse.reduce(escape(node["text"].to_s, node["marks"])) do |text, mark|
          case mark["type"]
          when "bold" then "**#{text}**"
          when "italic" then "*#{text}*"
          when "strike" then "~~#{text}~~"
          when "code" then "`#{text}`"
          when "link" then "[#{text}](#{mark.dig('attrs', 'href')})"
          else text
          end
        end
      end.join
    end

    def escape(text, marks)
      return text if Array(marks).any? { |mark| mark["type"] == "code" }

      text.gsub(/([\\`*_\[\]#])/) { "\\#{Regexp.last_match(1)}" }
    end
  end
end
