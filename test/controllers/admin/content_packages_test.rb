require "test_helper"

class Admin::ContentPackagesTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper

  DEMO = Rails.root.join("test/nibble_packages/demo")

  setup { sign_in_as users(:admin) }

  def zipped(dir) = Rack::Test::UploadedFile.new(StringIO.new(Nibble::Packages::Archive.write(dir)), "application/zip", original_filename: "package.zip")
  def report = flash[:import_report].with_indifferent_access

  def import(dir, **params) = process(:post, "/admin/utilities/content/import", params: { package: zipped(dir), mode: "create", **params })

  test "export downloads the site's content as a zip another site can import" do
    Nibble::Packages::Importer.new(DEMO).call

    get "/admin/utilities/content/export"

    assert_equal "application/zip", response.media_type
    assert_match(/content-example\.test-\d{4}-\d{2}-\d{2}\.zip/, response.headers["Content-Disposition"])
    Dir.mktmpdir do |dir|
      Nibble::Packages::Archive.extract(StringIO.new(response.body), into: dir)
      assert Pathname(dir).join("collections/posts/en/grids.yml").file?
      assert Nibble::Packages::Importer.new(dir).validate.ok?
    end
  end

  test "checking a package reports what it would do and writes nothing" do
    import(DEMO)

    assert_redirected_to "/admin/utilities/content"
    assert report[:ok]
    assert_not report[:imported]
    assert_operator report[:created], :>, 0
    assert_equal 0, Nibble::Records::Entry.count, "a check is only a check"
  end

  test "importing after a clean check writes the content" do
    import(DEMO, confirm: "1")

    assert report[:imported]
    assert Nibble::Records::Entry.exists?(slug: "grids")
  end

  test "a package with problems is reported and nothing lands" do
    Dir.mktmpdir do |dir|
      Pathname(dir).join("collections/posts/en").mkpath
      Pathname(dir).join("collections/posts/en/broken.yml").write("status: sideways\n")

      import(Pathname(dir), confirm: "1")
    end

    assert_not report[:ok]
    assert_match "status must be published or draft", report[:errors].join
    assert_equal 0, Nibble::Records::Entry.count
  end

  test "importing waits for a fresh password, since it rewrites content across the site" do
    Current.session.update!(elevated_at: 20.minutes.ago)

    import(DEMO, confirm: "1")

    assert_redirected_to content_admin_utilities_path
    assert_equal 0, Nibble::Records::Entry.count

    follow_redirect!
    assert_equal "admin/Confirm", JSON.parse(Nokogiri::HTML(response.body).at_css("script[data-page]").text)["component"]
  end

  test "export and import each need their own permission, not just the utilities screen" do
    sign_in_as users(:editor)
    assert Nibble::Access.can?(users(:editor), "utilities.view")

    get "/admin/utilities/content/export"
    assert_response :forbidden

    import(DEMO, confirm: "1")
    assert_response :forbidden
    assert_equal 0, Nibble::Records::Entry.count
  end

  test "an upload that isn't a zip is turned away with a plain reason" do
    process :post, "/admin/utilities/content/import",
      params: { package: Rack::Test::UploadedFile.new(StringIO.new("nope"), "application/zip", original_filename: "x.zip") }

    assert_match "isn't a readable zip file", flash[:alert]
  end
end
