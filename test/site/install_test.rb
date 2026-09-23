require "test_helper"

class SiteInstallTest < ActionDispatch::IntegrationTest
  SCRIPT = Rails.root.join("install.sh")

  # The home page tells people to run this straight from the network. It has to be the file this repository
  # installs from, byte for byte, or the command advertises one script and runs another.
  test "the install script is served exactly as it is written" do
    get "/install.sh"

    assert_response :success
    assert_equal SCRIPT.read, response.body
  end

  # Readable in a browser, because anyone sensible looks before running it.
  test "the install script is served as plain text" do
    get "/install.sh"

    assert_equal "text/plain", response.media_type
  end

  # Piped into bash, the script's own input is the script, and the installer's first question would read it.
  test "the installer's questions read the terminal, so the piped command on the home page can answer them" do
    assert_includes SCRIPT.read, "< /dev/tty"
  end
end
