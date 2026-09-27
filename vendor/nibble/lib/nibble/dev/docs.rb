module Nibble
  module Dev
    # Nibble's documentation as it ships with this release, so an agent reads what is true for the installed version.
    module Docs
      ROOT = Nibble.core_root.join("docs")

      module_function

      def tools
        [
          Tool.new(name: "search_docs", title: "Search Nibble's docs", read_only: true, handler: method(:search),
            description: "Search the documentation for the Nibble version this site runs: modelling content, theming, " \
                         "extending, running a site. Returns pages with the lines that matched; read_doc reads one.",
            input: Dev.schema({ "query" => { "type" => "string" }, "limit" => { "type" => "integer" } }, %w[query])),
          Tool.new(name: "read_doc", title: "Read a docs page", read_only: true, handler: method(:read),
            description: "One page of Nibble's documentation, as Markdown.",
            input: Dev.schema({ "path" => { "type" => "string", "description" => "As search_docs gives it, like theming/views.md" } }, %w[path]))
        ]
      end

      def pages = ROOT.glob("**/*.md").sort

      def search(input)
        terms = input["query"].to_s.downcase.scan(/[[:alnum:]_:.-]+/)
        return { "error" => "search for at least one word" } if terms.empty?

        scored = pages.filter_map do |page|
          text = page.read
          lines = text.lines
          title = text[/^title:\s*(.+)$/, 1] || lines.find { |line| line.start_with?("# ") }&.delete_prefix("# ")&.strip
          score = terms.sum { |term| text.downcase.scan(term).size + (title.to_s.downcase.include?(term) ? 10 : 0) }
          next if score.zero?

          matches = lines.each_with_index.select { |line, _| terms.any? { |term| line.downcase.include?(term) } }.first(3)
          { "path" => page.relative_path_from(ROOT).to_s, "title" => title, "score" => score,
            "lines" => matches.map { |line, index| "#{index + 1}: #{Dev.clip(line.strip, 200)}" } }
        end
        { "results" => scored.sort_by { |result| -result["score"] }.first((input["limit"] || 8).to_i.clamp(1, 30)) }
      end

      def read(input)
        page = ROOT.join(input["path"].to_s).expand_path
        unless page.to_s.start_with?("#{ROOT}/") && page.extname == ".md" && page.file?
          return { "error" => "no docs page #{input['path']}", "hint" => "search_docs gives the paths" }
        end

        { "path" => page.relative_path_from(ROOT).to_s, "markdown" => page.read }
      end
    end
  end
end
