class AssetFilesController < ActionController::Base
  include ActiveStorage::Streaming

  def show
    asset = Nibble::Records::Asset.kept.find_by(uuid: params[:uuid]) or return head(:not_found)
    preset = params[:preset] && Nibble::Assets.preset(params[:preset])
    return head(:not_found) if params[:preset] && !transformable?(asset, preset)

    canonical = asset.url(params[:preset], width: params[:w].presence&.to_i)
    return redirect_to(canonical) unless request.fullpath == canonical

    http_cache_forever(public: true) do
      if preset then send_transform(asset, preset)
      elsif asset.kind == "svg" then send_svg(asset)
      else send_blob_stream(asset.blob)
      end
    end
  end

  private

  def transformable?(asset, preset)
    return false unless preset && (Nibble::Assets.transformable?(asset) || Nibble::Assets.previewable?(asset))

    params[:w].blank? || Array(preset["srcset"]).include?(params[:w].to_i)
  end

  def send_svg(asset)
    response.headers["Content-Security-Policy"] = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; sandbox"
    send_data asset.blob.download, type: "image/svg+xml", disposition: :inline, filename: asset.filename
  end

  def send_transform(asset, preset)
    format = Nibble::Assets::Transform.format_for(asset, request.headers["Accept"])
    response.headers["Vary"] = "Accept"
    source = asset.blob
    if Nibble::Assets.previewable?(asset)
      source.preview({}).processed unless source.preview_image.attached?
      source = source.preview_image.blob
    end
    variant = source.variant(Nibble::Assets::Transform.transformations(asset, preset, width: params[:w].presence&.to_i, format:)).processed
    send_blob_stream(variant.image.blob, disposition: :inline)
  end
end
