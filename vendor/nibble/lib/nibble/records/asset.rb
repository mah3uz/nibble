module Nibble
  module Records
    class Asset < ::ApplicationRecord
      self.table_name = "assets"
      include Content

      FIELD_COLUMNS = %w[title alt caption credit].freeze
      COLUMNS = %w[folder focal_x focal_y focal_zoom edits tags filename].freeze
      ROTATIONS = [ 0, 90, 180, 270 ].freeze
      FLIPS = %w[horizontal vertical].freeze

      def self.record_type = "asset"

      belongs_to :blob, class_name: "ActiveStorage::Blob"

      scope :kept, -> { where(deleted_at: nil) }

      before_validation { self.uuid ||= SecureRandom.uuid }
      after_destroy_commit { blob.purge_later unless self.class.exists?(blob_id:) }

      validates :filename, :mime, :size, presence: true
      validates :focal_x, :focal_y, numericality: { in: 0..1 }, allow_nil: true
      validates :focal_zoom, numericality: { in: 1..10 }
      validate :focal_point_complete
      validate :edits_are_valid
      validate :folder_exists
      validate :tags_are_strings

      def blueprint_item = Nibble.schema.find(:blueprints, "assets/asset")
      def blueprint_definition = Blueprint.for(blueprint_item)

      def locale = Nibble.config.default_locale.code
      def extension = Assets.extension(filename)
      def image? = kind == "image"
      def focal = focal_x && { "x" => focal_x, "y" => focal_y }
      def display_title = title.presence || filename
      def url(preset = nil, width: nil) = Assets.url(self, preset, width:)
      def version = Digest::SHA256.hexdigest([ blob_id, focal_x, focal_y, focal_zoom, edits ].to_json)[0, 12]
      def rotation = edits["rotate"].to_i

      def rotated_size
        return nil unless width.to_i.positive? && height.to_i.positive?

        [ 90, 270 ].include?(rotation) ? [ height, width ] : [ width, height ]
      end

      def edited_size
        rotated_width, rotated_height = rotated_size || (return nil)
        crop = edits["crop"] or return [ rotated_width, rotated_height ]

        [ [ (crop["width"] * rotated_width).round, 1 ].max, [ (crop["height"] * rotated_height).round, 1 ].max ]
      end

      def thumbnail_url
        return url("cp-thumb") if Assets.transformable?(self) || Assets.previewable?(self)

        url if image? || kind == "svg"
      end

      def values = data.to_h.merge(FIELD_COLUMNS.index_with { |column| self[column] })
      def snapshot = values.merge(COLUMNS.index_with { |column| self[column] })

      def assign_snapshot(snapshot)
        snapshot = snapshot.stringify_keys
        (FIELD_COLUMNS + COLUMNS).each { |column| self[column] = snapshot[column] if snapshot.key?(column) }
        self.data = snapshot.except(*FIELD_COLUMNS, *COLUMNS)
      end

      def sync_file
        self.filename = Assets.clean_filename(blob.filename.to_s) if filename.blank?
        self.kind = Assets.kind_for(filename)
        self.mime = blob.content_type.presence || "application/octet-stream"
        self.size = blob.byte_size
        self.width, self.height, self.duration = blob.metadata.values_at("width", "height", "duration")
      end

      private

      def focal_point_complete
        errors.add(:focal_x, "needs both coordinates") if focal_x.nil? != focal_y.nil?
      end

      def folder_exists
        errors.add(:folder, "doesn't exist") unless folder == "" || AssetFolder.exists?(path: folder)
      end

      def edits_are_valid
        return errors.add(:edits, "must be a set of image edits") unless edits.is_a?(Hash)

        errors.add(:edits, "can only crop, rotate and flip") if (edits.keys - %w[crop rotate flip]).any?
        errors.add(:edits, "rotate by a quarter turn") unless ROTATIONS.include?(edits.fetch("rotate", 0))
        errors.add(:edits, "flip horizontally or vertically") unless edits["flip"].nil? || FLIPS.include?(edits["flip"])
        crop = edits["crop"] or return

        box = crop.is_a?(Hash) ? crop.values_at("x", "y", "width", "height") : []
        valid = box.size == 4 && box.all?(Numeric) && box[0] >= 0 && box[1] >= 0 && box[2].positive? && box[3].positive? &&
          box[0] + box[2] <= 1.0001 && box[1] + box[3] <= 1.0001
        errors.add(:edits, "crop must stay inside the image") unless valid
      end

      def tags_are_strings
        errors.add(:tags, "must be a list of words") unless tags.is_a?(Array) && tags.all?(String)
      end

      ActiveSupport.run_load_hooks(:nibble_asset, self)
    end
  end
end
