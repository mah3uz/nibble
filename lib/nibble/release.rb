module Nibble
  module Release
    MINIMUM_UPGRADE_FROM = "0.1.0".freeze
    RECORD = ".nibble/install.yml".freeze

    Blocker = Data.define(:reason)
    Installed = Data.define(:version, :commit, :at)

    class << self
      def blockers(from:, ruby: RUBY_VERSION, node: node_version, to: VERSION)
        [
          too_old(from, to),
          below_floor("ruby", ruby, ruby_floor),
          node && below_floor("node", node, node_floor)
        ].compact
      end

      def too_old(from, to = VERSION)
        return Blocker.new(reason: "this install has no recorded version") if from.blank?
        return nil if at_least?(from, MINIMUM_UPGRADE_FROM)

        Blocker.new(reason: "#{to} upgrades from #{MINIMUM_UPGRADE_FROM} and up; this install is #{from}, so go through #{MINIMUM_UPGRADE_FROM} first")
      end

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

      def below_floor(tool, running, floor)
        return nil if at_least?(running, floor)

        Blocker.new(reason: "#{tool} #{floor} or newer is needed; this machine has #{running}")
      end
    end
  end
end
