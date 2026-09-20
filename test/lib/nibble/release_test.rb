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
end
