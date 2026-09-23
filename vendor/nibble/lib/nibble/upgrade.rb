require "digest"
require "pathname"
require "yaml"

module Nibble
  # What decides whether a release can be taken. Plain Ruby, because bin/upgrade runs it before the new release's
  # gems are installed; the application loads it like the rest of Nibble.
  module Upgrade
    module_function

    # Nibble's files that no longer match the release they came from, or nil when the folder came from no release.
    def edited(folder)
      manifest = Pathname(folder).join("MANIFEST")
      return nil unless manifest.file?

      manifest.readlines.filter_map do |line|
        sha, path = line.chomp.split("  ", 2)
        file = Pathname(folder).join(path)
        path unless file.file? && Digest::SHA256.file(file).hexdigest == sha
      end
    end

    # Why the incoming release (its VERSION) can't be taken by a site on installed, if it can't. theme_manifest is the
    # site's own theme's theme.yml, or nil when the site uses one the release ships.
    def blockers(installed:, incoming:, ruby:, node:, theme_manifest: nil)
      to = incoming["version"]
      reasons = []
      reasons << "#{to} upgrades from #{incoming['minimum_upgrade_from']} and up; go through that first" unless at_least?(installed, incoming["minimum_upgrade_from"])
      reasons << "#{to} needs Ruby #{incoming['ruby']} or newer; this is #{ruby}" unless at_least?(ruby, incoming["ruby"])
      reasons << "#{to} needs Node #{incoming['node']} or newer; this is #{node || 'missing'}" unless node && at_least?(node, incoming["node"])
      if theme_manifest
        wanted = theme_manifest["nibble"].to_s[/\A[\^~]?(\d+)/, 1]
        reasons << "the site's theme is built for theme API #{wanted || 'unknown'}; #{to} speaks #{incoming['theme_api']}" unless wanted.to_i == incoming["theme_api"].to_i
      end
      reasons
    end

    def at_least?(version, floor) = Gem::Version.new(version.to_s) >= Gem::Version.new(floor.to_s)
  end
end
