module Nibble
  module Release
    # The oldest release this one can upgrade from; packed into the archive's VERSION.
    MINIMUM_UPGRADE_FROM = "0.1.0".freeze
    Installed = Data.define(:version, :at, :answers)

    class << self
      # Written by install and upgrade. The answers are what let an upgrade render a site's files again, so taking
      # defaults, or recording only a new version, keeps the ones already there.
      def record_install(version:, answers: nil, root: Rails.root)
        kept = answers.presence || installed(root:)&.answers || {}
        Metadata.write("install", { "version" => version, "at" => Date.current.to_s, "answers" => kept.deep_stringify_keys }, root:)
      end

      def installed(root: Rails.root)
        data = Metadata.read(root:)["install"] or return nil

        Installed.new(version: data["version"], at: data["at"], answers: (data["answers"] || {}).symbolize_keys)
      end

      def at_least?(version, floor) = Gem::Version.new(version.to_s) >= Gem::Version.new(floor.to_s)
    end
  end
end
