require_relative "../clean_failures"

class NibbleReleasesCommand < Rails::Command::Base
  extend CleanFailures
  namespace "nibble:releases"

  desc "feed PATH", "Write the release feed the control panel reads, from CHANGELOG.md"
  def feed(path)
    boot_application!
    releases = Nibble::Releases.publish(Rails.root.join("CHANGELOG.md"), path)
    say_status :write, "#{path} — #{releases.size} releases, newest #{releases.first&.dig('version')}", :green
  end
end
