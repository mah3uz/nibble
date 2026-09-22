require "test_helper"

class NibbleFilesPagesTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  teardown { Nibble.reset_schema! }

  def write(files)
    dir = Pathname(Dir.mktmpdir("nibble-content"))
    files.each do |path, text|
      dir.join(path).dirname.mkpath
      dir.join(path).binwrite(text)
    end
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "url" => "https://example.test",
      "locales" => [ { "code" => "en", "default" => true } ] },
      themes_path: Rails.root.join("test/nibble_themes"),
      site_schema_path: Rails.root.join("test/nibble_themes/no_site_schema"), content_path: dir,
      published_path: @published ||= Pathname(Dir.mktmpdir("nibble-published")))
    Nibble.reset_schema!
  end

  def image_bytes(width)
    Vips::Image.black(width, (width * 0.6).to_i).cast(:uchar).write_to_buffer(".png")
  end

  def page(id, title, body: "Words.")
    "---\nid: #{id}\ntitle: #{title}\n---\n\n#{body}\n"
  end

  # Nothing was written to the database, so this proves the page is served from the file and not from a row.
  test "a page written as a file is served without a record existing for it" do
    write("docs/index.md" => page("docs-home", "Docs"),
          "docs/users/index.md" => page("users", "Users"),
          "docs/users/installing.md" => page("installing", "Installing"))

    get "/docs/users/installing"

    assert_response :success
    assert_equal 0, Nibble::Records::Entry.where(collection: "docs").count, "no row backs a file-backed page"
    assert_equal "Installing", page_props.dig("props", "page", "title")
  end

  # The words are the point of the page, and a title arriving without them looks like success.
  test "the file's body reaches the view, in the field the blueprint writes as Markdown" do
    write("docs/index.md" => page("docs-home", "Docs", body: "The first paragraph."))

    get "/docs"

    assert_equal "<p>The first paragraph.</p>", page_props.dig("props", "page", "body").strip,
                 "rendered server-side, as a theme receives it"
  end

  test "a folder's own index.md answers at the folder's address" do
    write("docs/index.md" => page("docs-home", "Docs"))

    get "/docs"

    assert_response :success
    assert_equal "Docs", page_props.dig("props", "page", "title")
  end

  # A clash is refused where it is made, so it can never become a question of which one answers.
  test "a record cannot be saved onto an address a file already holds" do
    write("docs/index.md" => page("docs-home", "Docs"))

    result = Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "pages"), :create,
                                    { "title" => "Docs", "slug" => "docs" })

    assert_not result.ok?, "/docs is the folder's own page"
    assert_match "already used by", result.errors["uri"].to_a.join
  end

  test "an address no file holds is saved as normal" do
    write("docs/index.md" => page("docs-home", "Docs"))

    result = Nibble::Lifecycle.call(Nibble::Records::Entry.new(collection: "pages"), :create,
                                    { "title" => "Pricing", "slug" => "pricing" })

    assert result.ok?, result.errors.inspect
  end

  def published(relative) = Nibble.config.published_path.join(relative)

  # Served straight from public/ by whatever is in front, so a page's image never costs a Ruby request.
  test "an image beside a page is published under a digested name and linked by it" do
    write("docs/index.md" => page("docs-home", "Docs", body: "![A diagram](diagram.png)"),
          "docs/diagram.png" => "bytes")

    body = Nibble::Files.index.page("/docs").body
    url = body[%r{/nibble-assets/docs/diagram-[0-9a-f]{8}\.png}]

    assert url, "expected a digested url, got: #{body}"
    assert published(url.delete_prefix("/nibble-assets/")).file?, "the url names a file that was published"
  end

  # A page written as a file gets the same responsive image a page written in the panel does.
  test "a published image reaches the page with the widths it was published at" do
    write("docs/index.md" => page("docs-home", "Docs", body: "![A diagram](diagram.png)"),
          "docs/diagram.png" => image_bytes(1600))

    get "/docs"

    html = page_props.dig("props", "page", "body")

    assert_includes html, "640w"
    assert_includes html, 'sizes="100vw"'
  end

  # The digest is the content, so an edit publishes a new address and nothing has to be invalidated.
  test "editing an image changes the address it is published at" do
    write("docs/index.md" => page("docs-home", "Docs", body: "![A](diagram.png)"), "docs/diagram.png" => "one")
    before = Nibble::Files.index.page("/docs").body

    write("docs/index.md" => page("docs-home", "Docs", body: "![A](diagram.png)"), "docs/diagram.png" => "two")

    assert_not_equal before, Nibble::Files.index.page("/docs").body
  end

  test "a file that is not an image is never published" do
    write("docs/index.md" => page("docs-home", "Docs"), "docs/secret.txt" => "words")
    Nibble::Files.index

    assert_empty Dir.glob(published("docs/secret*"))
    assert_empty Dir.glob(published("docs/index*"))
  end

  # A published file that outlives the one it came from is the staleness this design exists to remove.
  test "an image whose file is gone stops being published" do
    write("docs/index.md" => page("docs-home", "Docs"), "docs/going.png" => "bytes")
    Nibble::Files.index
    assert_not_empty Dir.glob(published("docs/going-*.png"))

    write("docs/index.md" => page("docs-home", "Docs"))
    Nibble::Files.index

    assert_empty Dir.glob(published("docs/going-*.png"))
  end

  # Deleting the file is the whole of deleting the page: nothing is left behind to clean up.
  test "a page whose file is gone is gone" do
    write("docs/index.md" => page("docs-home", "Docs"), "docs/going.md" => page("going", "Going"))
    get "/docs/going"
    assert_response :success

    write("docs/index.md" => page("docs-home", "Docs"))
    get "/docs/going"

    assert_response :not_found
  end
end
