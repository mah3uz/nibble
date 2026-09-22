require "test_helper"

class NibbleFilesPagesTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  teardown { Nibble.reset_schema! }

  def write(files)
    dir = Pathname(Dir.mktmpdir("nibble-content"))
    files.each do |path, text|
      dir.join(path).dirname.mkpath
      dir.join(path).write(text)
    end
    Nibble.config = Nibble::Config.new({ "theme" => "starter", "url" => "https://example.test",
      "locales" => [ { "code" => "en", "default" => true } ] },
      themes_path: Rails.root.join("test/nibble_themes"),
      site_schema_path: Rails.root.join("test/nibble_themes/no_site_schema"), content_path: dir)
    Nibble.reset_schema!
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
