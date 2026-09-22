module Nibble
  module Assets
    module Transform
      FORMATS = { "image/avif" => "avif", "image/webp" => "webp" }.freeze

      module_function

      def format_for(asset, accept)
        FORMATS.find { |mime, format| accept.to_s.include?(mime) && encodable?(format) }&.last ||
          (asset.extension == "png" ? "png" : "jpg")
      end

      # libvips can report a format among its suffixes while lacking the encoder plugin that saves it — Debian
      # splits codecs like AV1 into separate packages, so ".avif" reads without ever being able to write. The
      # only way to know for certain is to try, once, and remember the answer for the life of the process.
      def encodable?(format)
        @encodable ||= {}
        @encodable.fetch(format) { @encodable[format] = probe_encodable(format) }
      end

      def probe_encodable(format)
        Vips::Image.black(1, 1).write_to_buffer(".#{format}")
        true
      rescue Vips::Error
        false
      end

      def transformations(asset, preset, width: nil, format: "jpg")
        width ||= preset["w"]
        height = (preset["h"] * width / preset["w"].to_f).round
        resize = preset["fit"] == "contain" ? { resize_to_limit: [ width, height ] } : crop(asset, width, height)
        edits(asset).merge(resize).merge(format:, saver: { quality: preset["q"] || 80 })
      end

      def edits(asset)
        steps = {}
        steps[:rot] = :"d#{asset.rotation}" if asset.rotation.positive?
        steps[:flip] = asset.edits["flip"].to_sym if asset.edits["flip"]
        width, height = asset.rotated_size
        box = asset.edits["crop"]
        if box && width
          left = (box["x"] * width).round.clamp(0, width - 1)
          top = (box["y"] * height).round.clamp(0, height - 1)
          steps[:extract_area] = [ left, top, (box["width"] * width).round.clamp(1, width - left), (box["height"] * height).round.clamp(1, height - top) ]
        end
        steps
      end

      def crop(asset, width, height)
        source_width, source_height = asset.edited_size || (return { resize_to_fill: [ width, height ] })

        scale = [ width / source_width.to_f, height / source_height.to_f ].max * asset.focal_zoom.to_f.clamp(1, 10)
        scaled_width = (source_width * scale).round
        scaled_height = (source_height * scale).round
        left = ((asset.focal_x || 0.5) * scaled_width - width / 2.0).round.clamp(0, scaled_width - width)
        top = ((asset.focal_y || 0.5) * scaled_height - height / 2.0).round.clamp(0, scaled_height - height)
        { resize: scale, crop: [ left, top, width, height ] }
      end
    end
  end
end
