require "test_helper"

class RepositoryTest < ActiveSupport::TestCase
  test "one place says where Nibble comes from, so moving it is a one-line change" do
    assert_match %r{\Ahttps://\S+\.git\z}, Nibble::REPOSITORY
  end

  test "the release feed is ours to publish, over TLS, at an address no site has to be told" do
    assert_match %r{\Ahttps://\S+\z}, Nibble::CHANGELOGS_FEED,
      "a site never sets this: an install has to know where to look without being told"
    refute_match %r{localhost|127\.0\.0\.1}, Nibble::CHANGELOGS_FEED
  end

  test "the installer downloads releases from the same repository the app knows about" do
    default = Rails.root.join("install.sh").read[/^\s*REPOSITORY="\$\{NIBBLE_REPOSITORY:-([^}]+)\}"/, 1]

    assert_equal Nibble::REPOSITORY[%r{github\.com/(.+?)\.git\z}, 1], default,
      "install.sh runs before the app exists, so it carries its own copy — this keeps the two from drifting"
  end

  test "Nibble's own site runs every release's behaviour from the release that brings it" do
    raised = Rails.root.join("config/nibble.yml").read[/^\s*load_defaults:\s*"([^"]+)"/, 1]

    assert_equal Nibble::VERSION, raised,
      "bin/nibble-release raises load_defaults with the version; behind it, nothing here runs what a release switched on"
  end

  test "the release command points at the same place" do
    assert_match "REPOSITORY", Rails.root.join("bin/nibble-release").read
  end
end
