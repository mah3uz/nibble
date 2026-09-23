module Nibble
  module Eject
    AREAS = { "vendor/nibble/frontend/nibble-admin/pages" => "site/cp/pages" }.freeze
    # Everything else was rendered once at install and is the site's to change.
    RESERVED = %w[vendor/nibble].freeze

    Ejection = Data.define(:source, :target, :commit, :at, :sha256)

    class Refused < Error; end

    class << self
      def run(source, root: Rails.root, force: false)
        source = normalise(source)
        target = target_for(source) or raise Refused, "#{source} isn't a file a site can eject (#{AREAS.keys.join(', ')})"
        raise Refused, "#{source} doesn't exist" unless root.join(source).file?
        raise Refused, "#{target} already exists — edit it, or pass --force to take a fresh copy" if root.join(target).file? && !force

        root.join(target).dirname.mkpath
        FileUtils.cp(root.join(source), root.join(target))
        record(Ejection.new(source:, target:, commit: commit(root:), at: Date.current.to_s,
                            sha256: Digest::SHA256.file(root.join(source)).hexdigest), root:)
      end

      def manifest(root: Rails.root)
        Metadata.read(root:)["ejected"].to_h.to_h do |source, entry|
          [ source, Ejection.new(source:, target: entry["target"], commit: entry["commit"], at: entry["at"], sha256: entry["sha256"]) ]
        end
      end

      def ejected?(source, root: Rails.root) = manifest(root:).key?(normalise(source))

      def stale(root: Rails.root)
        manifest(root:).values.select { |ejection| changed_since?(ejection, root:) }
      end

      def diff_since(ejection, root: Rails.root)
        return "" unless changed_since?(ejection, root:)

        IO.popen([ "git", "-C", root.to_s, "diff", "--stat", ejection.commit, "HEAD", "--", ejection.source ],
                 err: File::NULL, &:read)
      end

      # Ours as it was when copied, against ours as it is now: an upgrade replaces the original and leaves the copy.
      def changed_since?(ejection, root: Rails.root)
        if ejection.sha256.present?
          original = root.join(ejection.source)
          return !original.file? || Digest::SHA256.file(original).hexdigest != ejection.sha256
        end
        return false if ejection.commit.blank?

        return false unless git(root, "cat-file", "-e", "#{ejection.commit}^{commit}")

        git(root, "diff", "--quiet", ejection.commit, "HEAD", "--", ejection.source) == false
      end

      # Only meaningful on an install, whose record in config/nibble.yml names the upstream commit it came from.
      def unmanaged(root: Rails.root)
        installed = Release.installed(root:) or return []
        return [] if installed.commit.blank?
        return [] unless git(root, "cat-file", "-e", "#{installed.commit}^{commit}")

        changed(root, installed.commit)
      end

      def target_for(source)
        area = AREAS.keys.find { |prefix| source.start_with?("#{prefix}/") } or return nil

        source.sub(area, AREAS[area])
      end

      def commit(root: Rails.root)
        IO.popen([ "git", "-C", root.to_s, "rev-parse", "HEAD" ], err: File::NULL, &:read).strip.presence
      end

      private

      def normalise(source) = source.to_s.delete_prefix("./").delete_prefix("/")

      def record(ejection, root:)
        entries = manifest(root:).merge(ejection.source => ejection)
        Metadata.write("ejected", entries.sort.to_h { |source, entry| [ source, entry.to_h.stringify_keys.except("source") ] }, root:)
        ejection
      end

      # Only what a site changed or removed of ours: a file it added is its own, and cannot conflict.
      def changed(root, commit)
        out = IO.popen([ "git", "-C", root.to_s, "diff", "--name-only", "--diff-filter=MD", commit, "HEAD", "--", *RESERVED ],
          err: File::NULL, &:read)
        out.split("\n").map(&:strip).reject(&:empty?).sort
      end

      def git(root, *args) = system("git", "-C", root.to_s, *args, out: File::NULL, err: File::NULL)
    end
  end
end
