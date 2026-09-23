require "test_helper"

class Nibble::UpgradeTest < ActiveSupport::TestCase
  INCOMING = { "version" => "2.0.0", "minimum_upgrade_from" => "1.5.0", "ruby" => "3.4.1", "node" => "24.0.0", "theme_api" => 1 }.freeze

  def blockers(**overrides) = Nibble::Upgrade.blockers(installed: "1.5.0", incoming: INCOMING, ruby: "3.4.1", node: "24.0.0", **overrides)

  test "a site too old to upgrade in one step is told which release to go through" do
    assert_equal [ "2.0.0 upgrades from 1.5.0 and up; go through that first" ], blockers(installed: "1.0.0")
  end

  test "a site at the floor upgrades without complaint" do
    assert_empty blockers
  end

  test "a toolchain below what the release needs stops the upgrade before anything is touched" do
    assert_match "needs Ruby 3.4.1", blockers(ruby: "3.3.0").sole
    assert_match "needs Node 24.0.0", blockers(node: "22.0.0").sole
    assert_match "this is missing", blockers(node: nil).sole
  end

  test "a site's own theme built for another theme API stops the upgrade" do
    assert_empty blockers(theme_manifest: { "nibble" => "^1" })
    assert_match "theme API 2", blockers(theme_manifest: { "nibble" => "^2" }).sole
  end

  test "this checkout meets its own release's floors, so a release never ships one it cannot meet" do
    incoming = ReleaseArchive.new(root: Rails.root, out: Rails.root.join("tmp")).declared
    node = IO.popen([ "node", "--version" ], &:read).strip.delete_prefix("v")

    assert_empty Nibble::Upgrade.blockers(installed: Nibble::VERSION, incoming:, ruby: RUBY_VERSION, node:)
  end

  test "a folder no release came from has nothing to compare, rather than everything changed" do
    assert_nil Nibble::Upgrade.edited(Dir.mktmpdir("nibble-unreleased"))
  end

  test "an edit or a deletion in Nibble's files is found, so an upgrade never replaces it unannounced" do
    folder = Pathname(Dir.mktmpdir("nibble-released"))
    { "lib/a.rb" => "a", "lib/b.rb" => "b", "lib/c.rb" => "c" }.each { |path, body| folder.join(path).tap { _1.dirname.mkpath }.write(body) }
    folder.join("MANIFEST").write(%w[lib/a.rb lib/b.rb lib/c.rb].map { |path| "#{Digest::SHA256.hexdigest(folder.join(path).read)}  #{path}\n" }.join)
    assert_empty Nibble::Upgrade.edited(folder)

    folder.join("lib/a.rb").write("a, changed")
    folder.join("lib/c.rb").delete

    assert_equal %w[lib/a.rb lib/c.rb], Nibble::Upgrade.edited(folder)
  ensure
    FileUtils.rm_rf(folder) if folder
  end
end
