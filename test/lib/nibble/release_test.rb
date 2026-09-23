require "test_helper"

class Nibble::ReleaseTest < ActiveSupport::TestCase
  setup { @root = Pathname(Dir.mktmpdir("nibble-record")) }
  teardown { FileUtils.rm_rf(@root) }

  test "re-recording an install keeps the answers the install asked for" do
    Nibble::Release.record_install(version: "0.2.0", answers: { url: "https://notes.example" }, root: @root)
    Nibble::Release.record_install(version: "0.3.0", root: @root)

    assert_equal "https://notes.example", Nibble::Release.installed(root: @root).answers[:url],
                 "an upgrade re-records without them, and losing them stops it ever re-rendering a site's own files"
    assert_equal "0.3.0", Nibble::Release.installed(root: @root).version
  end

  test "versions compare as numbers, so the tenth release is newer than the ninth" do
    assert Nibble::Release.at_least?("0.10.0", "0.9.0")
    assert_not Nibble::Release.at_least?("0.9.0", "0.10.0")
  end
end
