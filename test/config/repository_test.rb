require "test_helper"

class RepositoryTest < ActiveSupport::TestCase
  test "one place says where Nibble comes from, so moving it is a one-line change" do
    assert_match %r{\Ahttps://\S+\.git\z}, Nibble::REPOSITORY
  end

  test "the release feed is ours to publish and points at a file, not an API" do
    assert_match %r{\Ahttps://\S+\.json\z}, Nibble::RELEASES_FEED,
      "a site never sets this: an install has to know where to look without being told"
  end

  test "the installer clones the same repository the app knows about" do
    default = Rails.root.join("install.sh").read[/^REPO="\$\{NIBBLE_REPO:-([^}]+)\}"/, 1]

    assert_equal Nibble::REPOSITORY, default,
      "install.sh runs before the app exists, so it carries its own copy — this keeps the two from drifting"
  end

  test "the release command points at the same place" do
    assert_match "REPOSITORY", Rails.root.join("bin/nibble-release").read
  end
end
