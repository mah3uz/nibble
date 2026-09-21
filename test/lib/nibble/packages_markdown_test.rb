require "test_helper"

class Nibble::PackagesMarkdownTest < ActiveSupport::TestCase
  include NibbleStarterHelper

  def folder(files)
    dir = Pathname(Dir.mktmpdir("nibble-markdown"))
    files.each do |path, content|
      dir.join(path).dirname.mkpath
      dir.join(path).write(content)
    end
    dir
  end

  def folder_for(dir) = Nibble::Packages::Folder.new("docs", root: dir, field: "body", navigation: "docs")

  # The site layer is the last to define a handle, which is how a site states a route of its own.
  def routed(route)
    dir = Pathname(Dir.mktmpdir("nibble-site-schema"))
    dir.join("collections").mkpath
    dir.join("collections/docs.yml").write(<<~YAML)
      schema: 1
      title: Docs
      route: "#{route}"
      structure:
        max_depth: 3
      blueprints: [doc]
      template: docs/show
      source:
        markdown: docs
        field: body
        navigation: docs
    YAML
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "url" => "https://example.test",
      "locales" => [ { "code" => "en", "default" => true } ] },
      themes_path: Rails.root.join("test/nibble_themes"), site_schema_path: dir)
    Nibble.reset_schema!
  end

  def entry_in(node) = Nibble::Records::Entry.find(node["entry"] || node["id"])

  def read(dir, **options)
    reader = Nibble::Packages::MarkdownReader.new(dir, collection: "posts", **options)
    [ reader.documents, reader.errors ]
  end

  test "a file becomes the document an import already knows how to write" do
    dir = folder("guides/testing.md" => "---\ntitle: Testing\norder: 2\n---\n\n# Testing\n\nHow we test.\n",
                 "guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n")

    documents, errors = read(dir)

    assert_empty errors
    testing = documents.find { |doc| doc.slug == "testing" }
    assert_equal "posts/guides/testing", testing.key, "the path is the key, so a page keeps its place"
    assert_equal "posts/guides", testing.parent_key, "a folder's index.md is the page its files sit under"
    assert_equal "Testing", testing.data["title"], "frontmatter is fields"
    assert_equal "# Testing\n\nHow we test.", testing.data["body"], "the body is the Markdown, frontmatter removed"
    assert_not testing.data.key?("order"), "order places the page in the tree; it is not a field of the blueprint"
  end

  test "the field the body lands in is the collection's to choose" do
    dir = folder("note.md" => "Just text.\n")

    documents, = read(dir, field: "notes")

    assert_equal "Just text.", documents.sole.data["notes"]
  end

  test "a page with nowhere to sit is reported rather than imported" do
    dir = folder("guides/testing.md" => "Orphan.\n")

    documents, errors = read(dir)

    assert_empty documents
    assert_match(/guides\/ has no index.md/, errors.sole)
  end

  test "position is a column Nibble sets, so a folder of files can state its own order" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n",
                 "guides/second.md" => "---\ntitle: Second\nposition: 2\n---\n\nB.\n",
                 "guides/first.md" => "---\ntitle: First\nposition: 1\n---\n\nA.\n")

    result = folder_for(dir).call
    assert result.ok?, result.report.errors.join("\n")

    ordered = Nibble::Records::Entry.where(collection: "docs").where.not(position: nil).order(:position).pluck(:title)
    assert_equal %w[First Second], ordered,
      "published_at is the only other handle on order, and a page in a folder has no publication date to sort by"
  end

  test "an index at the root is the collection's own page, not an error that loses the whole folder" do
    dir = folder("index.md" => "---\ntitle: Home\n---\n\nHome.\n",
                 "guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n")

    documents, errors = read(dir)

    assert_empty errors
    assert_equal [ "posts/guides", "posts/home" ], documents.map(&:key).sort,
      "refusing the root index used to write nothing at all for the collection, losing every other page with it"
  end

  test "a folder of Markdown imports as entries, through the pipeline a package already uses" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n",
                 "guides/testing.md" => "---\ntitle: Testing\n---\n\nHow we test.\n")
    reader = Nibble::Packages::MarkdownReader.new(dir, collection: "docs", field: "body")

    report = Nibble::Packages::Importer.new(dir, reader:).call

    assert report.ok?, report.errors.join("\n")
    testing = Nibble::Records::Entry.find_by!(slug: "testing")
    assert_equal "How we test.", testing.values["body"]
    assert_equal "guides", testing.parent&.slug, "the folder is the page above it"
    assert_equal "Testing", testing.title, "frontmatter reaches the columns an import sets, not only fields"
  end

  test "the folder decides what exists: a page whose file has gone is trashed, not left live" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n",
                 "guides/testing.md" => "---\ntitle: Testing\n---\n\nHow we test.\n")
    folder_for(dir).call

    dir.join("guides/testing.md").delete
    result = folder_for(dir).call

    assert result.ok?, result.report.errors.join("\n")
    assert_equal 1, result.trashed.size, "the page whose file went, and only that page"
    assert_nil Nibble::Records::Entry.kept.find_by(slug: "testing")
    assert Nibble::Records::Entry.kept.find_by(slug: "guides"), "the pages still written are left alone"
  end

  test "a folder addresses its pages by where they sit, so a site writes no route of its own" do
    dir = folder("index.md" => "---\ntitle: Docs\n---\n\nStart here.\n",
                 "something.md" => "---\ntitle: Something\n---\n\nA page.\n",
                 "a/index.md" => "---\ntitle: A\n---\n\nA folder.\n",
                 "a/b.md" => "---\ntitle: B\n---\n\nInside it.\n")

    result = folder_for(dir).call

    assert result.ok?, result.report.errors.join("\n")
    uri = ->(slug) { Nibble::Records::Entry.kept.find_by!(slug:).uri }
    assert_equal "/docs", uri.("home"), "the folder's own index.md answers where the folder does"
    assert_equal "/docs/something", uri.("something")
    assert_equal "/docs/a", uri.("a"), "a sub-folder's index.md answers at the sub-folder"
    assert_equal "/docs/a/b", uri.("b"), "and a page inside it keeps the folder it was written in"
  end

  test "a route that already places its own pages is left as the site wrote it" do
    routed("/docs{parent_uri}/{slug}")
    dir = folder("a/index.md" => "---\ntitle: A\n---\n\nA folder.\n",
                 "a/b.md" => "---\ntitle: B\n---\n\nInside it.\n")

    folder_for(dir).call

    assert_equal "/docs/docs/a/b", Nibble::Records::Entry.kept.find_by!(slug: "b").uri,
      "the site asked for parent_uri and got it, repetition and all: Nibble doesn't second-guess a written route"
  end

  test "changing where a collection lives moves the pages already imported" do
    dir = folder("a/index.md" => "---\ntitle: A\n---\n\nA folder.\n",
                 "a/b.md" => "---\ntitle: B\n---\n\nInside it.\n")
    folder_for(dir).call
    assert_equal "/docs/a/b", Nibble::Records::Entry.kept.find_by!(slug: "b").uri

    routed("/manual/{slug}")
    result = folder_for(dir).call

    assert result.ok?, result.report.errors.join("\n")
    assert_equal "/manual/a/b", Nibble::Records::Entry.kept.find_by!(slug: "b").uri,
      "a route is not a file, so nothing in the folder changed: the sync has to notice on its own"
  end

  test "running it again changes nothing, which is what makes it safe at every deploy" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\n---\n\nEverything.\n")
    first = folder_for(dir).call

    second = folder_for(dir).call

    assert_equal 2, first.report.created.size, "the page, and the navigation its folders describe"
    assert_empty second.report.created
    assert_empty second.trashed
    assert_equal "Everything.", Nibble::Records::Entry.kept.sole.values["body"]
  end

  test "a row of a grid keeps the id it was given, so a deploy that re-runs this writes nothing" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\nlinks:\n  - label: One\n  - label: Two\n---\n\nEverything.\n")
    folder_for(dir).call
    before = Nibble::Records::Entry.kept.sole.values["links"].map { |row| row["id"] }

    second = folder_for(dir).call

    assert_empty second.report.updated, "nothing in the folder changed, so nothing should be written"
    assert_equal before, Nibble::Records::Entry.kept.sole.values["links"].map { |row| row["id"] },
      "a row id is bookkeeping, not content: minting new ones would rewrite the page on every deploy"
    assert_equal %w[One Two], Nibble::Records::Entry.kept.sole.values["links"].map { |row| row["label"] }
  end

  test "a source folder cannot reach outside content/, which is the only place files are read from" do
    inside = { "markdown" => "docs" }
    outside = [ { "markdown" => "../app" }, { "markdown" => "/etc" }, { "markdown" => "docs/../../app" } ]

    assert Nibble::Schema::Rules::SOURCE.(inside)
    assert Nibble::Schema::Rules::SOURCE.({ "markdown" => "content/docs" })
    assert_equal Nibble::Packages::Folder.path("docs"), Nibble::Packages::Folder.path("content/docs"),
      "the prefix is optional, and means the same folder either way"
    assert_equal Rails.root.join("content/docs"), Nibble::Packages::Folder.path("docs")
    outside.each { |source| assert_not Nibble::Schema::Rules::SOURCE.(source), "#{source['markdown']} should be refused" }
  end

  test "a link between files becomes a link between pages, and survives either of them moving" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\n---\n\nStart with [testing](testing.md).\n",
                 "guides/testing.md" => "---\ntitle: Testing\n---\n\nBack to [guides](index.md#top), or [home](../start.md).\n",
                 "start.md" => "---\ntitle: Start\n---\n\nHere.\n")
    folder_for(dir).call

    guides = Nibble::Records::Entry.kept.find_by!(slug: "guides")
    testing = Nibble::Records::Entry.kept.find_by!(slug: "testing")

    assert_equal "Start with [testing](nibble://page/docs/guides/testing).", guides.values["body"],
      "stored as a reference, so the file's own path is not baked into the page"
    html = testing.blueprint_fields.add_values(testing.values).augment.values["body"]
    assert_includes html, %(href="#{guides.uri}#top"), "and rendered as wherever that page is now"
    assert_includes html, %(href="#{Nibble::Records::Entry.kept.find_by!(slug: 'start').uri}")
  end

  test "a link to a page that does not exist renders as a dead link, not as a scheme nobody can follow" do
    dir = folder("start.md" => "---\ntitle: Start\n---\n\nSee [gone](gone.md).\n")
    folder_for(dir).call

    entry = Nibble::Records::Entry.kept.sole
    html = entry.blueprint_fields.add_values(entry.values).augment.values["body"]

    assert_includes html, %(href="#")
    assert_not_includes html, "nibble://"
  end

  test "an image beside the pages becomes an asset, and the same image twice stays one asset" do
    dir = folder("start.md" => "---\ntitle: Start\n---\n\n![A desk](images/desk.jpg)\n")
    dir.join("images").mkpath
    FileUtils.cp(file_fixture("photo.jpg"), dir.join("images/desk.jpg"))

    folder_for(dir).call
    asset = Nibble::Records::Asset.kept.sole
    entry = Nibble::Records::Entry.kept.sole

    assert_equal "docs/images", asset.folder, "filed where it was written, not in a heap"
    assert_equal "![A desk](nibble://asset/#{asset.id})", entry.values["body"]

    folder_for(dir).call

    assert_equal 1, Nibble::Records::Asset.kept.count, "running again uploads it again only if it changed"
    assert_includes entry.reload.blueprint_fields.add_values(entry.values).augment.values["body"], asset.url
  end

  test "the folders are the tree a sidebar needs, in the order the pages ask for" do
    dir = folder("guides/index.md" => "---\ntitle: Guides\norder: 2\n---\n\nAll of them.\n",
                 "guides/testing.md" => "---\ntitle: Testing\n---\n\nHow.\n",
                 "start.md" => "---\ntitle: Start\norder: 1\n---\n\nHere.\n")

    folder_for(dir).call

    tree = Nibble::Records::NavigationTree.find_by!(handle: "docs").tree
    assert_equal 2, tree.size
    assert_equal "start", entry_in(tree.first).slug, "order decides, so a sidebar does not read alphabetically"
    assert_equal "guides", entry_in(tree.second).slug
    assert_equal "testing", entry_in(tree.second["children"].sole).slug, "a folder's pages sit under its page"
  end
end
