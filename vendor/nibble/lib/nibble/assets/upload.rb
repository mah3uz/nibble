module Nibble
  module Assets
    module Upload
      module_function

      def refusal(filename, byte_size)
        return "#{File.extname(filename.to_s).presence || 'This file type'} files can't be uploaded." unless Assets.uploadable?(filename)

        "#{filename} is larger than #{Nibble.config.max_upload_bytes / 1.megabyte} MB." if byte_size.to_i > Nibble.config.max_upload_bytes
      end

      def call(blob, attrs = {}, actor: nil)
        if (message = refusal(blob.filename.to_s, blob.byte_size))
          blob.purge_later
          return Lifecycle::Result.new(status: :invalid, record: Records::Asset.new, errors: { "file" => [ message ] }, referrers: [])
        end

        filename = Assets.clean_filename(blob.filename.to_s)
        blob = sanitize(blob) if Assets.kind_for(blob.filename.to_s) == "svg"
        blob = dedupe(blob)
        result = Lifecycle.call(Records::Asset.new(blob:, filename:), :create, attrs, actor:)
        Jobs::AnalyzeAsset.perform_later(result.record) if result.ok? && !blob.analyzed?
        result
      end

      def replace(asset, blob, actor: nil)
        if (message = refusal(blob.filename.to_s, blob.byte_size) || kind_change(asset, blob.filename.to_s))
          blob.purge_later
          return Lifecycle::Result.new(status: :invalid, record: asset, errors: { "file" => [ message ] }, referrers: [])
        end

        blob = sanitize(blob) if Assets.kind_for(blob.filename.to_s) == "svg"
        blob = dedupe(blob)
        result = Lifecycle.call(asset, :replace, { "blob_id" => blob.id }, actor:)
        Jobs::AnalyzeAsset.perform_later(asset) if result.ok? && !blob.analyzed?
        result
      end

      def kind_change(asset, filename)
        family = ->(kind) { kind == "svg" ? "image" : kind }
        from = family.(asset.kind)
        return if family.(Assets.kind_for(filename)) == from

        noun = from == "image" ? "an image" : "a #{from} file"
        "Reupload #{noun} to replace #{noun}."
      end

      def sanitize(blob)
        original = blob.download
        clean = SvgSanitizer.call(original)
        return blob if clean == original

        replacement = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(clean), filename: blob.filename.to_s, content_type: "image/svg+xml")
        blob.purge_later
        replacement
      end

      def dedupe(blob)
        existing = ActiveStorage::Blob.where(checksum: blob.checksum, byte_size: blob.byte_size).where.not(id: blob.id)
          .where(id: Records::Asset.select(:blob_id)).first
        return blob unless existing

        blob.purge_later
        existing
      end
    end
  end
end
