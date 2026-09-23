require "test_helper"

class Nibble::ReleaseTest < ActiveSupport::TestCase
  test "an install too old to upgrade in one step is told which release to go through" do
    blocker = Nibble::Release.too_old("0.0.1", "2.0.0")

    assert blocker, "upgrading across a version we no longer migrate from must not silently proceed"
    assert_match Nibble::Release::MINIMUM_UPGRADE_FROM, blocker.reason
  end

  test "an install at or above the floor upgrades without complaint" do
    assert_nil Nibble::Release.too_old(Nibble::Release::MINIMUM_UPGRADE_FROM)
    assert_nil Nibble::Release.too_old("99.0.0")
  end

  test "an install with no recorded version is blocked rather than assumed current" do
    assert Nibble::Release.too_old(nil), "guessing here would run migrations the install may not be ready for"
    assert Nibble::Release.too_old("")
  end

  test "a toolchain below what the release needs blocks before anything is merged" do
    blockers = Nibble::Release.blockers(from: Nibble::VERSION, ruby: "3.0.0", node: "18.0.0")
    reasons = blockers.map(&:reason)

    assert_equal 2, blockers.size, "both the ruby and node floors must report, not just the first"
    assert(reasons.any? { |reason| reason.start_with?("ruby") })
    assert(reasons.any? { |reason| reason.start_with?("node") })
  end

  test "this checkout satisfies its own floors, so a release never ships one it cannot meet" do
    assert_empty Nibble::Release.blockers(from: Nibble::VERSION)
  end

  test "the floors are read from the files that already declare them" do
    assert_equal File.read(Rails.root.join(".ruby-version")).strip.delete_prefix("ruby-"), Nibble::Release.ruby_floor
    assert_equal JSON.parse(Rails.root.join("package.json").read).dig("engines", "node").delete_prefix(">="), Nibble::Release.node_floor
  end

  test "an upgrade is gated on the floors of the release being taken, not the one installed" do
    repo_with_releases

    taken = Nibble::Release.declared("v0.2.0", root: @root)
    blockers = Nibble::Release.blockers(from: "0.2.0", ruby: "3.4.1", node: "24.0.0", release: taken)

    assert_equal 1, blockers.size, "reading the installed release's floors would let a site onto code it cannot run"
    assert_match "node 99.0.0", blockers.sole.reason
    assert_empty Nibble::Release.blockers(from: "0.1.0", ruby: "3.4.1", node: "24.0.0",
                                          release: Nibble::Release.declared("v0.1.0", root: @root)),
                 "the same machine clears the release it is actually on"
  end

  test "how far back a release upgrades from is the taken release's answer" do
    repo_with_releases

    blocker = Nibble::Release.too_old("0.1.0", *Nibble::Release.declared("v0.2.0", root: @root).then { |release|
      [ release.version, release.minimum_upgrade_from ]
    })

    assert blocker, "0.2.0 raised its floor to 0.2.0, so an 0.1.0 install has to go through it"
    assert_match "go through 0.2.0", blocker.reason
  end

  test "releases are ordered by version, so the tenth is newer than the ninth" do
    repo_with_releases
    tag("v0.10.0")

    assert_equal "v0.10.0", Nibble::Release.latest(root: @root), "sorting these as text would offer an older release as the newest"
    assert_equal %w[v0.1.0 v0.2.0 v0.10.0], Nibble::Release.tags(root: @root)
  end

  test "a ref that declares no version is refused rather than taken for a release" do
    repo_with_releases
    write("vendor/nibble/lib/nibble.rb", "module Nibble; end")
    tag("not-a-release")

    assert_raises(Nibble::Error) { Nibble::Release.declared("not-a-release", root: @root) }
  end

  test "re-recording an install keeps the answers the install asked for" do
    root = Pathname(Dir.mktmpdir("nibble-record"))
    Nibble::Release.record_install(version: "0.2.0", commit: "abc", answers: { url: "https://notes.example" }, root:)
    Nibble::Release.record_install(version: "0.3.0", commit: "def", root:)

    assert_equal "https://notes.example", Nibble::Release.installed(root:).answers[:url],
                 "an upgrade re-records without them, and losing them stops it ever re-rendering a site's own files"
  ensure
    FileUtils.rm_rf(root)
  end

  private

  def repo_with_releases
    @root = Pathname(Dir.mktmpdir("nibble-release"))
    write("vendor/nibble/lib/nibble/release.rb", %(MINIMUM_UPGRADE_FROM = "0.1.0"))
    write(".ruby-version", "3.4.1")
    release("0.1.0", node: "24.0.0")
    release("0.2.0", node: "99.0.0", minimum: "0.2.0")
  end

  def release(version, node:, minimum: nil)
    write("vendor/nibble/lib/nibble.rb", %(VERSION = "#{version}"))
    write("package.json", { engines: { node: ">=#{node}" } }.to_json)
    write("vendor/nibble/lib/nibble/release.rb", %(MINIMUM_UPGRADE_FROM = "#{minimum}")) if minimum
    tag("v#{version}")
  end

  def tag(name)
    git("add", "-A")
    git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", name)
    git("tag", name)
  end

  def git(*args) = system("git", "-C", @root.to_s, *args, out: File::NULL, err: File::NULL)

  def write(relative, body)
    git("init", "-q") unless @root.join(".git").exist?
    path = @root.join(relative)
    path.dirname.mkpath
    path.write(body)
  end

  # Installing again into a live site must not move the baseline to the site's own HEAD: every file it had
  # touched since would then read as one of ours, changed in place.
  test "installing again keeps the commit a site was upgraded to" do
    root = Pathname(Dir.mktmpdir("record"))
    Nibble::Release.record_install(version: "1.0.0", commit: "abc123", root:)
    Nibble::Release.record_install(version: "1.0.0", root:)

    assert_equal "abc123", Nibble::Release.installed(root:).commit
  ensure
    FileUtils.rm_rf(root)
  end

  test "an upgrade moves the baseline deliberately" do
    root = Pathname(Dir.mktmpdir("record"))
    Nibble::Release.record_install(version: "1.0.0", commit: "abc123", root:)
    Nibble::Release.record_install(version: "1.1.0", commit: "def456", root:)

    assert_equal "def456", Nibble::Release.installed(root:).commit
  ensure
    FileUtils.rm_rf(root)
  end
end
