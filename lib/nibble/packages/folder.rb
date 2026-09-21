module Nibble
  module Packages
    # A collection whose pages are written as Markdown in a folder: the folder decides what exists.
    class Folder
      ROOT = "content".freeze
      IMAGES = %w[png jpg jpeg gif webp avif svg].freeze

      Result = Data.define(:report, :trashed, :collection) do
        def ok? = report.ok?
      end

      # Written with or without the prefix: content/docs and docs are the same folder.
      def self.path(value)
        parts = value.to_s.split("/")
        parts.shift if parts.first == ROOT
        Rails.root.join(ROOT, *parts)
      end

      def self.declared = Nibble.schema.all(:collections).select { |item| item.data["source"].is_a?(Hash) }

      def self.for(handle, dry_run: false)
        item = Nibble.schema.collection(handle) or raise Error, "no collection '#{handle}'"
        source = item.data["source"] or raise Error, "collection '#{handle}' has no source folder"
        new(handle, root: path(source["markdown"]), field: source["field"], navigation: source["navigation"], dry_run:)
      end

      # Where a page is written, which is what the control panel shows instead of letting anyone edit it.
      def self.file_for(entry)
        source = Nibble.schema.collection(entry.collection)&.data&.dig("source") or return nil

        slugs = []
        record = entry
        while record
          slugs.unshift(record.slug)
          record = record.parent
        end
        # A page with pages under it is a folder, and a folder's page is its index.
        file = entry.children.kept.exists? ? [ *slugs, "index.md" ] : [ *slugs[0..-2], "#{slugs.last}.md" ]
        path(source["markdown"]).join(*file).relative_path_from(Rails.root).to_s
      end

      def initialize(handle, root:, field: nil, navigation: nil, dry_run: false)
        @handle = handle
        @root = Pathname(root)
        @field = field
        @navigation = navigation
        @dry_run = dry_run
      end

      def call
        reader = MarkdownReader.new(@root, collection: @handle, field: @field, navigation: @navigation,
                                   images: @dry_run ? {} : images)
        report = Importer.new(@root, mode: "update", dry_run: @dry_run, reader:).call
        return Result.new(report:, trashed: [], collection: @handle) unless report.ok? && !@dry_run

        Result.new(report:, trashed: trash(reader.documents), collection: @handle)
      end

      private

      # An image beside the pages is an asset like any other, in a folder that mirrors where it was written.
      def images
        Dir.glob("**/*.{#{IMAGES.join(',')}}", base: @root).sort.filter_map do |relative|
          asset = asset_for(relative) or next nil
          [ relative, asset.id.to_s ]
        end.to_h
      end

      def asset_for(relative)
        folder = [ @handle, File.dirname(relative) ].reject { |part| part == "." }.join("/")
        filename = Assets.clean_filename(File.basename(relative))
        existing = Records::Asset.kept.find_by(folder:, filename:)
        return existing if existing && existing.blob.checksum == checksum(relative)

        blob = ActiveStorage::Blob.create_and_upload!(io: @root.join(relative).open, filename:)
        return Assets::Upload.replace(existing, blob).record if existing

        Assets::Upload.call(blob, { "folder" => folder }).record
      end

      def checksum(relative) = Digest::MD5.base64digest(@root.join(relative).read)

      def trash(documents)
        keys = documents.select { |doc| doc.kind == "collections" }.map(&:key).to_set
        entries = Records::Entry.kept.where(collection: @handle).includes(:parent)
        entries.reject { |entry| keys.include?(key_of(entry)) }
               .each { |entry| Lifecycle.call(entry, :trash, {}, mode: :import) }
               .map { |entry| entry.uri.presence || entry.slug }
      end

      def key_of(entry)
        slugs = []
        while entry
          slugs.unshift(entry.slug)
          entry = entry.parent
        end
        [ @handle, *slugs ].join("/")
      end
    end
  end
end
