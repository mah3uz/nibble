module Nibble
  module Assets
    KINDS = {
      "image" => %w[jpg jpeg png gif webp avif],
      "svg" => %w[svg],
      "video" => %w[h264 mp4 m4v ogv webm mov mpeg mpg mkv],
      "audio" => %w[aac flac m4a mp3 ogg wav]
    }.freeze

    UPLOADABLE = %w[
      7z aac aiff asc asf avi avif bmp cap cin csv dfxp doc docx dotm dotx fla flac flv gif gz gzip h264 heic heif hevc itt
      jp2 jpeg jpg jpx js json lrc m2t m4a m4v mcc md mid mkv mov mp3 mp4 mpc mpeg mpg mpsub ods odt ogg ogv pdf png potx pps
      ppsm ppsx ppt pptm pptx ppz pxd qt ram rar rm rmi rmvb rt rtf sami sbv scc sdc sitd smi srt stl sub svg swf sxc sxw tar
      tds tgz tif tiff ttml txt vob vsd vtt wav webm webp wma wmv xls xlsx zip
    ].freeze

    TRANSFORMABLE = %w[jpg jpeg png webp avif].freeze

    CP_PRESETS = {
      "cp-thumb" => { "w" => 400, "h" => 400, "fit" => "contain" },
      "cp-large" => { "w" => 1600, "h" => 1600, "fit" => "contain" }
    }.freeze

    class << self
      def extension(filename) = File.extname(filename.to_s).delete_prefix(".").downcase

      def unused(before:)
        Records::Asset.kept.where(created_at: ...before).where.not(id: used_ids).order(:folder, :filename)
      end

      # Relations only follow live values, so an image placed in a pending draft is counted from the draft itself.
      def used_ids
        live = Records::Relation.where(target_type: "asset").includes(:source).filter_map do |relation|
          relation.target_id unless relation.source.nil? || relation.source.trashed?
        end
        drafted = Records::Draft.includes(:record).flat_map do |draft|
          next [] if draft.record.nil? || draft.record.trashed?

          RecordValues.new(draft.record).relations(draft.data.to_h).filter_map { |_, type, id, _| id.to_i if type == "asset" }
        end
        (live + drafted).uniq
      end

      # Asset files hang off assets.blob_id rather than an attachment, so "unattached" alone would include every one of them.
      def stray_blobs(before:)
        ActiveStorage::Blob.unattached.where(created_at: ...before).where.not(id: Records::Asset.select(:blob_id))
      end

      def kind_for(filename)
        ext = extension(filename)
        KINDS.find { |_, extensions| extensions.include?(ext) }&.first || "file"
      end

      def uploadable?(filename) = (UPLOADABLE + Nibble.config.asset_extensions).include?(extension(filename))
      def transformable?(asset) = TRANSFORMABLE.include?(extension(asset.filename))
      def previewable?(asset) = asset.kind == "video" && ActiveStorage::Previewer::VideoPreviewer.ffmpeg_exists?

      def presets = CP_PRESETS.merge(Nibble.config.asset_presets)
      def preset(name) = presets[name.to_s]

      def clean_filename(filename)
        ext = extension(filename)
        base = File.basename(filename.to_s, File.extname(filename.to_s)).parameterize.presence || "file"
        ext.empty? ? base : "#{base}.#{ext}"
      end

      def output_size(asset, preset_name)
        preset = preset_name && preset(preset_name)
        return [ asset.width, asset.height ] unless preset

        return [ preset["w"], preset["h"] ] if preset["fit"] == "crop"

        width, height = asset.edited_size || (return [ nil, nil ])
        scale = [ preset["w"] / width.to_f, preset["h"] / height.to_f, 1 ].min
        [ (width * scale).round, (height * scale).round ]
      end

      def swap(value, from, to)
        case value
        when Array then value.map { |item| swap(item, from, to) }
        when Hash
          swapped = value.transform_values { |item| swap(item, from, to) }
          return swapped unless swapped["asset"].to_s == from.id.to_s

          swapped.merge("asset" => to.id.to_s, **(swapped.key?("src") ? { "src" => to.url } : {}))
        else value
        end
      end

      def url(asset, preset = nil, width: nil)
        path = [ "", "media", asset.uuid, preset, asset.filename ].compact.join("/")
        query = { w: width, v: asset.version }.compact.to_query
        "#{path}?#{query}"
      end
    end
  end
end
