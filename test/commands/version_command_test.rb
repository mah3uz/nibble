require "test_helper"

class VersionCommandTest < ActiveSupport::TestCase
  test "prints the running release alone, so a script can use it as it is" do
    out, = capture_io { Rails::Command.invoke("nibble:version") }

    assert_equal "#{Nibble::VERSION}\n", out
  end
end
