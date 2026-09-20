require "test_helper"

# No renderer checks these yet, so nothing else would notice a link rotting.
class DocsTest < ActiveSupport::TestCase
  DOCS = Rails.root.join("docs")
  REQUIRED_FRONTMATTER = %w[title description order].freeze
  LINK = /(?<!\!)\[[^\]]*\]\(([^)#]+)(?:#[^)]*)?\)/
  IMAGE = /!\[[^\]]*\]\(([^)]+)\)/

  def pages = Dir.glob(DOCS.join("**/*.md")).sort

  test "every page carries the frontmatter a renderer needs to place it" do
    missing = pages.filter_map do |page|
      front = File.read(page)[/\A---\n(.*?)\n---\n/m, 1]
      keys = front.to_s.scan(/^(\w+):/).flatten
      absent = REQUIRED_FRONTMATTER - keys
      "#{relative(page)}: #{absent.join(', ')}" if absent.any?
    end

    assert_empty missing, "pages without title, description and order:\n#{missing.join("\n")}"
  end

  test "every link between pages resolves, so a moved page cannot rot quietly" do
    assert_empty broken(LINK), "links pointing at nothing:\n#{broken(LINK).join("\n")}"
  end

  test "every image resolves" do
    assert_empty broken(IMAGE), "images pointing at nothing:\n#{broken(IMAGE).join("\n")}"
  end

  test "links between pages end in .md, which is what a file-based renderer follows" do
    wrong = pages.flat_map do |page|
      File.read(page).scan(LINK).flatten.reject { |target| external?(target) || target.end_with?(".md") || target.start_with?("images/") }
        .map { |target| "#{relative(page)} -> #{target}" }
    end

    assert_empty wrong, "links that are not to a .md page:\n#{wrong.join("\n")}"
  end

  private

  def broken(pattern)
    pages.flat_map do |page|
      File.read(page).scan(pattern).flatten.reject { |target| external?(target) }
        .reject { |target| Pathname(page).dirname.join(target).exist? }
        .map { |target| "#{relative(page)} -> #{target}" }
    end
  end

  def external?(target) = target.start_with?("http://", "https://", "mailto:")

  def relative(page) = Pathname(page).relative_path_from(Rails.root).to_s
end
