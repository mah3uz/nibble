module Nibble
  module Packages
    # A collection whose pages are written as Markdown in a folder: the folder decides what exists.
    class Folder
      Result = Data.define(:report, :trashed, :collection) do
        def ok? = report.ok?
      end

      def self.declared = Nibble.schema.all(:collections).select { |item| item.data["source"].is_a?(Hash) }

      def self.for(handle, dry_run: false)
        item = Nibble.schema.collection(handle) or raise Error, "no collection '#{handle}'"
        source = item.data["source"] or raise Error, "collection '#{handle}' has no source folder"
        new(handle, root: Rails.root.join(source["markdown"]), field: source["field"], dry_run:)
      end

      def initialize(handle, root:, field: nil, dry_run: false)
        @handle = handle
        @root = Pathname(root)
        @field = field
        @dry_run = dry_run
      end

      def call
        reader = MarkdownReader.new(@root, collection: @handle, field: @field)
        report = Importer.new(@root, mode: "update", dry_run: @dry_run, reader:).call
        return Result.new(report:, trashed: [], collection: @handle) unless report.ok? && !@dry_run

        Result.new(report:, trashed: trash(reader.documents), collection: @handle)
      end

      private

      def trash(documents)
        keys = documents.map(&:key).to_set
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
