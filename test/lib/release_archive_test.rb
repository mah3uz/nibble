require "test_helper"

class ReleaseArchiveTest < ActiveSupport::TestCase
  setup do
    @out = Pathname(Dir.mktmpdir("nibble-release"))
    @built = ReleaseArchive.new(root: Rails.root, out: @out.join("one"), mtime: Time.at(1_800_000_000)).build
    @entries = read(@built.archive)
  end

  teardown { FileUtils.rm_rf(@out) }

  def read(archive)
    entries = {}
    Zlib::GzipReader.open(archive) do |gzip|
      Gem::Package::TarReader.new(gzip).each { |entry| entries[entry.full_name] = [ entry.header.mode, entry.read.to_s ] }
    end
    entries
  end

  def top = "nibble-#{Nibble::VERSION}/"

  test "the archive is vendor/nibble and nothing else, so unpacking it can only ever replace that folder" do
    assert(@entries.keys.all? { |name| name.start_with?(top) })
    assert_includes @entries.keys, "#{top}lib/nibble.rb"
    assert_includes @entries.keys, "#{top}templates/Gemfile"
    assert_not_includes @entries.keys, "#{top}test/test_helper.rb"
  end

  test "Nibble's own tests stay in this repository and never reach a site" do
    assert_empty @entries.keys.grep(/__tests__/)
  end

  test "the same tree always packs to the same bytes, so the published checksum means one thing" do
    again = ReleaseArchive.new(root: Rails.root, out: @out.join("two"), mtime: Time.at(1_800_000_000)).build

    assert_equal @built.sha256, again.sha256
    assert_equal "#{@built.sha256}  #{@built.archive.basename}\n", @built.sums.read
  end

  test "the manifest checks every file, so an upgrade can tell a site's edits from ours" do
    manifest = @entries.fetch("#{top}MANIFEST").last.lines.to_h { |line| line.chomp.split("  ", 2).reverse }

    assert_equal @entries.keys.map { |name| name.delete_prefix(top) }.sort - [ "MANIFEST" ], manifest.keys.sort
    manifest.each { |path, sha| assert_equal Digest::SHA256.hexdigest(@entries.fetch("#{top}#{path}").last), sha, path }
  end

  test "a new site starts from the versions this repository was tested with, not whatever resolves that day" do
    assert_equal Rails.root.join("Gemfile.lock").read, @entries.fetch("#{top}locks/Gemfile.lock").last
    assert_equal Rails.root.join("package-lock.json").read, @entries.fetch("#{top}locks/package-lock.json").last
  end

  test "scripts keep their executable bit, or a site's first bin/rails fails" do
    assert_equal 0o755, @entries.fetch("#{top}templates/bin/rails").first
    assert_equal 0o644, @entries.fetch("#{top}templates/config/routes.rb").first
  end

  test "VERSION carries what an upgrade checks before touching anything" do
    declared = YAML.safe_load(@entries.fetch("#{top}VERSION").last)

    assert_equal Nibble::VERSION, declared["version"]
    assert_equal Nibble::Release::MINIMUM_UPGRADE_FROM, declared["minimum_upgrade_from"]
    assert_equal Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-"), declared["ruby"]
    assert_equal JSON.parse(Nibble.core_root.join("package.json").read).dig("engines", "node").delete_prefix(">="), declared["node"]
    assert_equal Nibble::THEME_API_VERSION, declared["theme_api"]
  end
end
