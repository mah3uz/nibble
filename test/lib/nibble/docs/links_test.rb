require "test_helper"

class DocsLinksTest < ActiveSupport::TestCase
  DOCS = Nibble.core_root.join("docs")
  PAGES = DOCS.glob("**/*.md")

  # The docs site supplies the screenshots and the changelog; neither ships in this folder.
  SUPPLIED_BY_DOCS_SITE = [ %r{\A(\.\./)+images/cp/[\w-]+\.png\z}, %r{\A(\.\./)+changelogs/index\.md\z} ].freeze

  def anchors(file)
    @anchors ||= {}
    @anchors[file] ||= Nokogiri::HTML5.fragment(Nibble::Markdown.render(file.read)).css("[id]").map { |node| node["id"] }
  end

  def links(file)
    file.read.gsub(/^```.*?^```/m, "").gsub(/`[^`\n]*`/, "").scan(/\]\(([^)\s]+)\)/).flatten
  end

  test "every relative link in the docs resolves to a page, and every anchor to a heading in it" do
    broken = PAGES.flat_map do |file|
      links(file).filter_map do |link|
        next if link.match?(%r{\A([a-z][a-z0-9+.-]*:|/)}i)

        path, anchor = link.split("#", 2)
        next if path.present? && SUPPLIED_BY_DOCS_SITE.any? { |pattern| path.match?(pattern) }

        target = path.blank? ? file : file.dirname.join(path).cleanpath
        if !target.file?
          "#{file.relative_path_from(DOCS)}: #{link} (no such page)"
        elsif anchor.present? && !anchors(target).include?(anchor)
          "#{file.relative_path_from(DOCS)}: #{link} (no such heading)"
        end
      end
    end

    assert_empty broken, "broken docs links:\n#{broken.join("\n")}"
  end

  # The docs site gives each page the URL /docs/<file name>, and a section's index.md takes its folder's name.
  test "no two docs pages share a file name, which the docs site would put at the same URL" do
    slugs = PAGES.group_by do |file|
      parts = file.relative_path_from(DOCS).to_s.delete_suffix(".md").split("/")
      parts.last == "index" ? parts[-2] : parts.last
    end

    assert_empty slugs.select { |_, files| files.size > 1 }.transform_values { |files| files.map { |file| file.relative_path_from(DOCS).to_s } }
  end

  test "every docs page has its own id and an order, since the docs site addresses and places pages by them" do
    fronts = PAGES.to_h { |file| [ file.relative_path_from(DOCS).to_s, Nibble::Markdown.front_matter(file.read) ] }
    ids = fronts.values.map { |front| front["id"] }

    assert_equal ids.uniq, ids
    assert_not_includes ids, nil
    assert_empty fronts.select { |_, front| front["order"].nil? }.keys
  end
end
