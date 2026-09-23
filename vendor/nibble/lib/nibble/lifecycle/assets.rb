module Nibble
  class Lifecycle
    class Assets < Handler
      ACTIONS = %w[create save replace trash restore].freeze

      def create
        invalid!(:blob, "is required") unless record.blob

        record.sync_file
        apply!(incoming({}))
        emit("record.created", "changes" => diff({}, record.snapshot))
      end

      def save
        before = record.snapshot
        apply!(incoming(before))
        emit("record.saved", "changes" => diff(before, record.snapshot))
      end

      def replace
        blob = ActiveStorage::Blob.find_by(id: attrs["blob_id"]) or invalid!(:file, "is required")
        before = record.snapshot
        previous = record.blob
        extension = Nibble::Assets.extension(blob.filename.to_s)
        record.blob = blob
        record.edits = {}
        record.focal_zoom = 1
        record.filename = "#{File.basename(record.filename, '.*')}#{".#{extension}" if extension.present?}"
        record.sync_file
        record.save!
        previous.purge_later unless previous == blob || Records::Asset.exists?(blob_id: previous.id)
        emit("record.saved", "changes" => diff(before, record.snapshot))
      end

      def trash = trash_record!

      def restore
        invalid!(:base, "This asset isn't in the trash.") unless record.trashed?

        record.deleted_at = nil
        record.save!
        emit("record.restored")
      end

      private

      def column_keys = Records::Asset::COLUMNS

      def normalized_edits(edits)
        edits = edits.to_h.stringify_keys.slice("crop", "rotate", "flip").compact_blank
        edits["rotate"] = edits["rotate"].to_i % 360 if edits.key?("rotate")
        edits.delete("rotate") if edits["rotate"] == 0
        crop = edits["crop"].is_a?(Hash) ? edits["crop"].stringify_keys.slice("x", "y", "width", "height").transform_values { |v| Float(v, exception: false) } : nil
        crop = nil if crop && crop.values_at("x", "y").all?(&:zero?) && crop.values_at("width", "height").all? { |v| v.to_f >= 0.9999 }
        crop ? edits.merge("crop" => crop) : edits.except("crop")
      end

      def renamed(filename)
        return record.filename if filename.blank?

        Nibble::Assets.clean_filename("#{File.basename(filename.to_s, '.*')}.#{record.extension}")
      end

      def apply!(snapshot)
        snapshot["folder"] = snapshot["folder"].to_s.delete_prefix("/").delete_suffix("/")
        invalid!(:folder, "can only use lowercase letters, numbers, dashes and underscores") unless snapshot["folder"].empty? || snapshot["folder"].match?(Records::AssetFolder::PATH)
        snapshot["filename"] = renamed(snapshot["filename"]) if snapshot.key?("filename")
        snapshot["edits"] = normalized_edits(snapshot["edits"])
        snapshot["focal_zoom"] = (snapshot["focal_zoom"].presence || 1).to_f
        snapshot["tags"] = Array(snapshot["tags"]).map { |tag| tag.to_s.strip }.compact_blank.uniq
        validate_fields!(snapshot, full: true)
        Records::AssetFolder.ensure!(snapshot["folder"])
        record.assign_snapshot(stored(snapshot))
        record.save!
      end
    end
  end
end
