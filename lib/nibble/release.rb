module Nibble
  module Release
    MINIMUM_UPGRADE_FROM = "0.1.0".freeze
    RECORD = ".nibble/install.yml".freeze

    Blocker = Data.define(:reason)
    Installed = Data.define(:version, :commit, :at)
    Declared = Data.define(:version, :minimum_upgrade_from, :ruby_floor, :node_floor)

    class << self
      def blockers(from:, ruby: RUBY_VERSION, node: node_version, to: VERSION, release: here(to))
        [
          too_old(from, release.version, release.minimum_upgrade_from),
          below_floor("ruby", ruby, release.ruby_floor),
          node && below_floor("node", node, release.node_floor)
        ].compact
      end

      def too_old(from, to = VERSION, minimum = MINIMUM_UPGRADE_FROM)
        return Blocker.new(reason: "this install has no recorded version") if from.blank?
        return nil if at_least?(from, minimum)

        Blocker.new(reason: "#{to} upgrades from #{minimum} and up; this install is #{from}, so go through #{minimum} first")
      end

      def here(to = VERSION) = Declared.new(version: to, minimum_upgrade_from: MINIMUM_UPGRADE_FROM, ruby_floor:, node_floor:)

      # An upgrade is gated on the floors of the release being taken, which are only readable from its tag.
      def declared(ref, root: Rails.root)
        version = show(ref, "lib/nibble.rb", root)[/VERSION = "([^"]+)"/, 1]
        raise Error, "#{ref} doesn't declare a Nibble version, so it isn't a release" if version.blank?

        Declared.new(
          version:,
          minimum_upgrade_from: show(ref, "lib/nibble/release.rb", root)[/MINIMUM_UPGRADE_FROM = "([^"]+)"/, 1].presence || version,
          ruby_floor: show(ref, ".ruby-version", root).strip.delete_prefix("ruby-"),
          node_floor: JSON.parse(show(ref, "package.json", root).presence || "{}").dig("engines", "node").to_s.delete_prefix(">=").presence || "0"
        )
      end

      def tags(root: Rails.root)
        git("tag", "--list", "v*", root:).lines.map(&:strip)
          .select { |tag| Gem::Version.correct?(tag.delete_prefix("v")) }
          .sort_by { |tag| Gem::Version.new(tag.delete_prefix("v")) }
      end

      def latest(root: Rails.root) = tags(root:).last

      # Written by install and upgrade: without it there is no baseline to tell a site's edits from ours.
      def record_install(version:, commit:, root: Rails.root)
        file = root.join(RECORD)
        file.dirname.mkpath
        file.write({ "version" => version, "commit" => commit, "at" => Date.current.to_s }.to_yaml)
      end

      def installed(root: Rails.root)
        file = root.join(RECORD)
        return nil unless file.file?

        data = YAML.safe_load_file(file) || {}
        Installed.new(version: data["version"], commit: data["commit"], at: data["at"])
      end

      def at_least?(version, floor) = Gem::Version.new(version.to_s) >= Gem::Version.new(floor.to_s)

      def ruby_floor = Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-")

      def node_floor
        engines = JSON.parse(Rails.root.join("package.json").read)["engines"].to_h
        engines["node"].to_s.delete_prefix(">=").presence || "0"
      end

      def node_version
        IO.popen([ "node", "--version" ], err: File::NULL, &:read).strip.delete_prefix("v").presence
      rescue Errno::ENOENT
        nil
      end

      private

      def git(*args, root:) = IO.popen([ "git", "-C", root.to_s, *args ], err: File::NULL, &:read)

      def show(ref, path, root) = git("show", "#{ref}:#{path}", root:)

      def below_floor(tool, running, floor)
        return nil if at_least?(running, floor)

        Blocker.new(reason: "#{tool} #{floor} or newer is needed; this machine has #{running}")
      end
    end
  end
end
