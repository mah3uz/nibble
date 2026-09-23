require "digest"
require "fileutils"
require "json"
require "pathname"
require "rubygems/package"
require "stringio"
require "yaml"
require "zlib"

# Packs vendor/nibble as a release: VERSION, MANIFEST and the tested lockfiles added, Nibble's own JS tests left out. The same tree and
# commit always give the same bytes, so the checksum published beside the archive means one thing.
class ReleaseArchive
  Built = Data.define(:version, :archive, :sums, :sha256)

  FOLDER = "vendor/nibble".freeze
  # A new site starts from the versions this repository was tested with, rather than whatever resolves that day.
  LOCKS = %w[Gemfile.lock package-lock.json].freeze
  LEFT_OUT = %r{(\A|/)__tests__/}

  def initialize(root:, out:, mtime: nil)
    @root = Pathname(root)
    @out = Pathname(out)
    @mtime = mtime
  end

  def build
    version = declared.fetch("version")
    name = "nibble-#{version}"
    entries = files.to_h { |path| [ path, @root.join(FOLDER, path) ] }
    added = { "VERSION" => declared.to_yaml.delete_prefix("---\n") }
    LOCKS.each { |lock| added["locks/#{lock}"] = @root.join(lock).read }
    added["MANIFEST"] = manifest(entries, added)

    @out.mkpath
    archive = @out.join("#{name}.tar.gz")
    write(archive, name, entries, added)
    sha256 = Digest::SHA256.file(archive).hexdigest
    sums = @out.join("SHA256SUMS")
    sums.write("#{sha256}  #{archive.basename}\n")
    Built.new(version:, archive:, sums:, sha256:)
  end

  # What an upgrade checks before it touches anything: the release, what it upgrades from, and the floors it needs.
  def declared
    @declared ||= begin
      nibble = @root.join(FOLDER, "lib/nibble.rb").read
      {
        "version" => nibble[/VERSION = "([^"]+)"/, 1],
        "minimum_upgrade_from" => @root.join(FOLDER, "lib/nibble/release.rb").read[/MINIMUM_UPGRADE_FROM = "([^"]+)"/, 1],
        "ruby" => @root.join(".ruby-version").read.strip.delete_prefix("ruby-"),
        "node" => JSON.parse(@root.join(FOLDER, "package.json").read).dig("engines", "node").to_s.delete_prefix(">="),
        "theme_api" => nibble[/THEME_API_VERSION = (\d+)/, 1].to_i
      }
    end
  end

  # Tracked files and new ones not yet ignored, as they are on disk; a release runs on a clean tree, so that is the tag.
  def files
    listed = IO.popen([ "git", "-C", @root.to_s, "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", FOLDER ], &:read)
    listed.split("\0").uniq.map { |path| path.delete_prefix("#{FOLDER}/") }
      .reject { |path| path.match?(LEFT_OUT) }
      .select { |path| @root.join(FOLDER, path).file? }
      .sort
  end

  private

  def manifest(entries, added)
    sums = entries.map { |path, source| [ path, Digest::SHA256.file(source).hexdigest ] } +
           added.map { |path, body| [ path, Digest::SHA256.hexdigest(body) ] }
    sums.sort.map { |path, sha| "#{sha}  #{path}\n" }.join
  end

  def write(archive, name, entries, added)
    time = mtime
    # The tar writer seeks back to fill in each header, which a gzip stream can't do.
    tarball = StringIO.new("".b)
    Gem::Package::TarWriter.new(tarball) do |tar|
      entries.each do |path, source|
        tar.add_file("#{name}/#{path}", source.executable? ? 0o755 : 0o644, time) { |io| io.write(source.binread) }
      end
      added.sort.each { |path, body| tar.add_file("#{name}/#{path}", 0o644, time) { |io| io.write(body) } }
    end
    File.open(archive, "wb") do |file|
      gzip = Zlib::GzipWriter.new(file)
      gzip.mtime = time
      gzip.write(tarball.string)
      gzip.finish
    end
  end

  # The release commit's time, not a constant: Bootsnap caches by modification time, and a site's files must look
  # newer after an upgrade than before it.
  def mtime
    @mtime || Time.at(IO.popen([ "git", "-C", @root.to_s, "log", "-1", "--format=%ct" ], &:read).to_i)
  end
end
