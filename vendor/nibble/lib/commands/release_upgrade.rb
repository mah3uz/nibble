require "digest"
require "fileutils"
require "net/http"
require "pathname"
require "rbconfig"
require "yaml"

# The installed release's half of an upgrade: fetch the next release, check it is the one published, and hand over to
# its bin/upgrade. A fix to this lands a release late, so it does no more than that, and needs nothing booted.
module ReleaseUpgrade
  private

  def take_release(version, passed_on, resume: false)
    $stdout.sync = true
    # Refuse before anything else: a deployed environment would fail on its own credentials rather than say why.
    environment = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
    fail!("upgrade on a workstation and deploy the result; never in place on #{environment}") unless environment == "development"

    root = Pathname(APP_PATH).dirname.parent
    finish_unfinished(root, version, passed_on, resume)
    if system("git", "-C", root.to_s, "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL)
      dirty = IO.popen([ "git", "-C", root.to_s, "status", "--porcelain" ], &:read).strip
      fail!("the working tree isn't clean; commit or stash first, so git can show what the upgrade changed") unless dirty.empty?
    end

    work = root.join("tmp/upgrade")
    FileUtils.rm_rf(work)
    work.mkpath
    archive = fetch(version, root, work)
    verify(archive, work.join("SHA256SUMS"))

    system("tar", "-xzf", archive.to_s, "-C", work.to_s) or fail!("#{archive.basename} couldn't be unpacked")
    incoming = work.glob("nibble-*/").first or fail!("#{archive.basename} holds no release")
    puts "handing over to #{incoming.basename}"
    exec(RbConfig.ruby, incoming.join("bin/upgrade").to_s, *passed_on, chdir: root.to_s)
  end

  # Swapped in but never recorded: the kept previous release says the upgrade stopped after the swap. Starting again would
  # swap a second time over the copy that is the way back, so only --resume carries on, from where it stopped.
  def finish_unfinished(root, version, passed_on, resume)
    recorded = NibbleHelp.recorded.to_h["version"]
    running = NibbleHelp.running
    unfinished = recorded && recorded != running && root.join("tmp/nibble-#{recorded}").directory?
    fail!("there is no unfinished upgrade to resume") if resume && !unfinished
    return unless unfinished

    unless resume
      fail!("the upgrade from #{recorded} to #{running} didn't finish. Fix the problem it stopped on, then run " \
            "bin/rails nibble:upgrade --resume to finish it; or go back: rm -rf vendor/nibble && mv tmp/nibble-#{recorded} vendor/nibble, " \
            "git checkout site/types.d.ts, and restore the database from storage/upgrades")
    end
    fail!("--resume finishes the upgrade to #{running}; it can't take #{version}") if version && version.delete_prefix("v") != running
    puts "finishing the upgrade from #{recorded} to #{running}"
    exec(RbConfig.ruby, root.join("vendor/nibble/bin/upgrade").to_s, "--resume", *passed_on, chdir: root.to_s)
  end

  # A local archive, with its SHA256SUMS beside it, stands in for a download: for trying a release before it is out.
  def fetch(version, root, work)
    unless (local = ENV["NIBBLE_ARCHIVE"].to_s.strip).empty?
      source = Pathname(local).expand_path
      FileUtils.cp([ source, source.dirname.join("SHA256SUMS") ], work)
      return work.join(source.basename)
    end

    slug = ENV["NIBBLE_REPOSITORY"].to_s.strip
    slug = root.join("vendor/nibble/lib/nibble.rb").read[%r{REPOSITORY = "https://github\.com/(.+?)\.git"}, 1] if slug.empty?
    version = (version || latest(slug)).delete_prefix("v")
    puts "fetching Nibble #{version}"
    base = "https://github.com/#{slug}/releases/download/v#{version}"
    archive = work.join("nibble-#{version}.tar.gz")
    archive.binwrite(download("#{base}/#{archive.basename}"))
    work.join("SHA256SUMS").write(download("#{base}/SHA256SUMS"))
    archive
  end

  def verify(archive, sums)
    expected = sums.read.lines.map(&:split).find { |_, name| name == archive.basename.to_s }&.first
    actual = Digest::SHA256.file(archive).hexdigest
    fail!("#{archive.basename} doesn't match its published checksum; nothing has changed") unless expected == actual
  end

  # The release page redirects to the latest tag; GitHub's API would say the same, but rate-limits shared addresses.
  def latest(slug)
    uri = URI("https://github.com/#{slug}/releases/latest")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(Net::HTTP::Get.new(uri, "User-Agent" => "nibble-upgrade")) }
    response["location"].to_s[%r{/releases/tag/v([^/]+)\z}, 1] or fail!("#{slug} has no release to upgrade to yet")
  end

  # Release downloads redirect to wherever GitHub stores them.
  def download(url, redirects = 5)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(Net::HTTP::Get.new(uri, "User-Agent" => "nibble-upgrade"))
    end
    return download(response["location"], redirects - 1) if response.is_a?(Net::HTTPRedirection) && redirects.positive?
    fail!("#{url} answered #{response.code}") unless response.is_a?(Net::HTTPSuccess)

    response.body
  end

  def fail!(message) = abort("upgrade refused: #{message}")
end
