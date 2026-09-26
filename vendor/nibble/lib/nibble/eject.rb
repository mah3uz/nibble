module Nibble
  module Eject
    AREAS = { "vendor/nibble/frontend/nibble-cp/pages" => "site/cp/pages" }.freeze
    Ejection = Data.define(:source, :target, :at, :sha256)

    class Refused < Error; end

    class << self
      def run(source, root: Rails.root, force: false)
        source = normalise(source)
        target = target_for(source) or raise Refused, "#{source} isn't a file a site can eject (#{AREAS.keys.join(', ')})"
        raise Refused, "#{source} doesn't exist" unless root.join(source).file?
        raise Refused, "#{target} already exists — edit it, or pass --force to take a fresh copy" if root.join(target).file? && !force

        root.join(target).dirname.mkpath
        FileUtils.cp(root.join(source), root.join(target))
        record(Ejection.new(source:, target:, at: Date.current.to_s, sha256: Digest::SHA256.file(root.join(source)).hexdigest), root:)
      end

      def manifest(root: Rails.root)
        Metadata.read(root:)["ejected"].to_h.to_h do |source, entry|
          [ source, Ejection.new(source:, target: entry["target"], at: entry["at"], sha256: entry["sha256"]) ]
        end
      end

      def ejected?(source, root: Rails.root) = manifest(root:).key?(normalise(source))

      def stale(root: Rails.root)
        manifest(root:).values.select { |ejection| changed_since?(ejection, root:) }
      end

      # Ours as it was when copied, against ours as it is now: an upgrade replaces the original and leaves the copy.
      def changed_since?(ejection, root: Rails.root)
        return false if ejection.sha256.blank?

        original = root.join(ejection.source)
        !original.file? || Digest::SHA256.file(original).hexdigest != ejection.sha256
      end

      # Nibble's files changed in place rather than ejected, which the next upgrade refuses to replace. A checkout that
      # wasn't installed from a release has no MANIFEST to compare against.
      def unmanaged(root: Rails.root)
        Upgrade.edited(root.join("vendor/nibble")).to_a.map { |path| "vendor/nibble/#{path}" }
      end

      def target_for(source)
        area = AREAS.keys.find { |prefix| source.start_with?("#{prefix}/") } or return nil

        source.sub(area, AREAS[area])
      end

      private

      def normalise(source) = source.to_s.delete_prefix("./").delete_prefix("/")

      def record(ejection, root:)
        entries = manifest(root:).merge(ejection.source => ejection)
        Metadata.write("ejected", entries.sort.to_h { |source, entry| [ source, entry.to_h.stringify_keys.except("source") ] }, root:)
        ejection
      end
    end
  end
end
