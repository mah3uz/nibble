module Nibble
  module Cp
    class UploadsController < BaseController
      # Re-encoded rather than sent as is: a staged file hasn't been checked, and only a real image survives decoding.
      def preview
        blob = Nibble::Assets::Staged.find_for(params[:id], Nibble::Current.user)
        return head(:not_found) unless blob && Nibble::Assets::TRANSFORMABLE.include?(Nibble::Assets.extension(blob.filename))

        size = Nibble::Assets.preset("cp-thumb")
        format = Nibble::Assets.extension(blob.filename) == "png" ? "png" : "jpg"
        image = blob.open { |file| ImageProcessing::Vips.source(file).resize_to_limit(size["w"], size["h"]).convert(format).call }
        response.headers["Cache-Control"] = "private, no-store"
        send_data image.read, type: Mime::Type.lookup_by_extension(format).to_s, disposition: :inline
      rescue Vips::Error, ImageProcessing::Error
        head :unprocessable_content
      ensure
        image&.close!
      end
    end
  end
end
