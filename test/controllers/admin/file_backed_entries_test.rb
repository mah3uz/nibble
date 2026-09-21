require "test_helper"

class Admin::FileBackedEntriesTest < ActionDispatch::IntegrationTest
  include NibbleStarterHelper
  include SessionTestHelper

  setup do
    sign_in_as users(:admin)
    @folder = Pathname(Dir.mktmpdir("nibble-docs"))
    @folder.join("testing.md").write("---\ntitle: Testing\n---\n\nHow we test.\n")
    Nibble::Packages::Folder.new("docs", root: @folder, field: "body").call
    @entry = Nibble::Records::Entry.find_by!(slug: "testing")
  end

  test "a page written in files opens, and says where it is written instead of offering to save it" do
    get edit_admin_collection_entry_path("docs", @entry)

    assert_response :success
    props = page_props["props"]
    assert_equal false, props.dig("can", "edit"), "the file is the source, so the form is read-only"
    assert_match(/testing\.md\z/, props.dig("source", "file"))
    assert_equal "bin/rails nibble:content:markdown", props.dig("source", "command")
  end

  test "a save is refused, so an edit cannot be lost at the next deploy" do
    patch admin_collection_entry_path("docs", @entry), params: { entry: { title: "Edited in the panel" } }

    assert_redirected_to edit_admin_collection_entry_path("docs", @entry)
    assert_equal "Testing", @entry.reload.title
  end
end
