module Nibble
  module Cp
    class MediaController < BaseController
      before_action { authorize!("assets.view") }
      before_action :load_asset, only: %i[show update destroy duplicate reupload replace]

      def index
        listing = Nibble::Cp::AssetListing.new(user: Nibble::Current.user, params:)
        props = { listing: listing.props, folders: listing.folders, folder: listing.folder, folder_options: listing.folder_options,
                  asset_id: params[:asset].presence&.to_i, can: abilities }
        return render(json: props) if request.format.json?

        render inertia: "cp/media/Index", props:
      end

      def show
        fields = @asset.blueprint_definition.fields.add_values(@asset.values)
        render json: {
          asset: Nibble::Cp::AssetListing.new(user: Nibble::Current.user).row(@asset, usage.size).merge(
            "mime" => @asset.mime, "focal" => @asset.focal, "focal_zoom" => @asset.focal_zoom, "edits" => @asset.edits, "tags" => @asset.tags, "created_at" => @asset.created_at.utc.iso8601,
            "preview" => @asset.url(@asset.image? && Nibble::Assets.transformable?(@asset) ? "cp-large" : nil),
            "download_url" => rails_blob_path(@asset.blob, disposition: "attachment", only_path: true),
            "lock_version" => @asset.lock_version
          ),
          blueprint: @asset.blueprint_definition.to_publish_h,
          values: fields.pre_process.values,
          field_meta: fields.meta,
          usage:,
          folder_options: Nibble::Cp::AssetListing.new(user: Nibble::Current.user).folder_options,
          can: abilities
        }
      end

      def create
        authorize!("assets.upload")
        blob = ActiveStorage::Blob.find_signed(params.require(:signed_id)) or raise ActiveRecord::RecordNotFound
        respond(Nibble::Assets::Upload.call(blob, { "folder" => params[:folder].to_s }, actor: Nibble::Current.user), status: :created)
      end

      def update
        authorize!("assets.edit")
        respond(Nibble::Lifecycle.call(@asset, :save, attrs, actor: Nibble::Current.user))
      end

      def destroy
        authorize!("assets.delete")
        result = Nibble::Lifecycle.call(@asset, :trash, { "force" => params[:force].to_s == "true" }, actor: Nibble::Current.user)
        return render(json: { referrers: usage }, status: :conflict) if result.needs_confirmation?

        respond(result)
      end

      def duplicate
        authorize!("assets.upload")
        respond(Nibble::Lifecycle.call(duplicate_of(@asset), :create, copied_values(@asset).merge(attrs), actor: Nibble::Current.user), status: :created)
      end

      def reupload
        authorize!("assets.edit")
        blob = ActiveStorage::Blob.find_signed(params.require(:signed_id)) or raise ActiveRecord::RecordNotFound
        respond(Nibble::Assets::Upload.replace(@asset, blob, actor: Nibble::Current.user))
      end

      def replace
        authorize!("assets.edit")
        replacement = Nibble::Records::Asset.kept.find(params.require(:with))
        sources = Nibble::Records::Relation.where(target_type: "asset", target_id: @asset.id).includes(:source).filter_map(&:source).uniq
        sources = sources.reject(&:trashed?).select { |source| Nibble::Lifecycle::HANDLERS[source.record_type].constantize::ACTIONS.include?("replace_asset") }
        failures = sources.filter_map do |source|
          result = Nibble::Lifecycle.call(source, :replace_asset, { "from" => @asset.id, "to" => replacement.id }, actor: Nibble::Current.user)
          "#{usage_title(source)}: #{result.errors.values.flatten.first}" unless result.ok?
        end
        Nibble::Lifecycle.call(@asset, :trash, { "force" => true }, actor: Nibble::Current.user) if failures.empty? && params[:delete_original].to_s == "true"
        error = "Couldn't replace it in #{failures.to_sentence}, so #{@asset.filename} was kept there." if failures.any?
        render json: { replaced: sources.size - failures.size, failures:, error: }.compact, status: failures.any? ? :unprocessable_entity : :ok
      end

      BULK_ABILITIES = { "move" => "assets.edit", "tag" => "assets.edit", "duplicate" => "assets.upload", "trash" => "assets.delete" }.freeze

      def bulk
        authorize!(BULK_ABILITIES.fetch(params[:handle]) { raise ActiveRecord::RecordNotFound })
        assets = Nibble::Records::Asset.kept.where(id: Array(params[:ids])).to_a
        failures = assets.filter_map do |asset|
          result = bulk_change(asset)
          "#{asset.filename}: #{result.errors.values.flatten.first}" unless result.ok?
        end
        render json: { updated: assets.size - failures.size, failures: }, status: failures.any? ? :unprocessable_entity : :ok
      end

      def create_folder
        authorize!("assets.upload")
        name = params[:name].to_s.strip.parameterize
        path = [ params[:parent].presence, name ].compact.join("/")
        error = if name.blank? || !path.match?(Nibble::Records::AssetFolder::PATH) then "can't be blank"
        elsif Nibble::Records::AssetFolder.exists?(path:) then "already exists"
        end
        return render(json: { errors: { "name" => [ error ] } }, status: :unprocessable_entity) if error

        Nibble::Records::AssetFolder.ensure!(path)
        render json: { path: }, status: :created
      end

      def rename_folder
        authorize!("assets.edit")
        folder = Nibble::Records::AssetFolder.find_by!(path: params.require(:path))
        target = [ File.dirname(folder.path).delete_prefix("."), params.require(:name).to_s.parameterize ].compact_blank.join("/")
        return render(json: { errors: { "name" => [ "already exists" ] } }, status: :unprocessable_entity) if Nibble::Records::AssetFolder.exists?(path: target)

        Nibble::Records::AssetFolder.transaction do
          Nibble::Records::AssetFolder.where(path: folder.path).or(Nibble::Records::AssetFolder.where("path LIKE ?", "#{folder.path}/%")).find_each do |item|
            item.update!(path: item.path.sub(folder.path, target))
          end
          Nibble::Records::Asset.where(folder: folder.path).update_all(folder: target)
          Nibble::Records::Asset.where("folder LIKE ?", "#{folder.path}/%").find_each { |asset| asset.update_columns(folder: asset.folder.sub(folder.path, target)) }
        end
        render json: { path: target }
      end

      def destroy_folder
        authorize!("assets.delete")
        folder = Nibble::Records::AssetFolder.find_by!(path: params.require(:path))
        in_use = Nibble::Records::Asset.where(folder: folder.path).or(Nibble::Records::Asset.where("folder LIKE ?", "#{folder.path}/%")).exists?
        return render(json: { errors: { "path" => [ "isn't empty" ] } }, status: :unprocessable_entity) if in_use

        Nibble::Records::AssetFolder.where("path LIKE ?", "#{folder.path}/%").order(path: :desc).destroy_all
        folder.destroy!
        head :no_content
      end

      private

      def bulk_change(asset)
        case params[:handle]
        when "move" then Nibble::Lifecycle.call(asset, :save, { "folder" => params[:folder].to_s }, actor: Nibble::Current.user)
        when "tag" then Nibble::Lifecycle.call(asset, :save, { "tags" => asset.tags + [ params.require(:tag).to_s ] }, actor: Nibble::Current.user)
        when "duplicate" then Nibble::Lifecycle.call(duplicate_of(asset), :create, copied_values(asset), actor: Nibble::Current.user)
        else Nibble::Lifecycle.call(asset, :trash, { "force" => true }, actor: Nibble::Current.user)
        end
      end

      def copied_values(asset) = asset.snapshot.except("filename")

      def duplicate_of(asset)
        Nibble::Records::Asset.new(blob: asset.blob, filename: "#{File.basename(asset.filename, '.*')}-copy.#{asset.extension}".delete_suffix("."))
      end

      def load_asset
        @asset = Nibble::Records::Asset.kept.find(params[:id])
      end

      def attrs
        raw = params.fetch(:asset, {})
        raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
        raw.to_h
      end

      def respond(result, status: :ok)
        return render(json: { errors: result.errors.transform_values { |messages| Array(messages) } }, status: :unprocessable_entity) if result.invalid?
        return render(json: { errors: result.errors }, status: :conflict) if result.conflict?

        render json: { asset: Nibble::Cp::AssetListing.new(user: Nibble::Current.user).row(result.record, 0) }, status:
      end

      def abilities
        %w[upload edit delete].index_with { |action| Nibble::Access.can?(Nibble::Current.user, "assets.#{action}") }
      end

      def usage
        @usage ||= Nibble::Records::Relation.where(target_type: "asset", target_id: @asset.id).includes(:source).filter_map do |relation|
          source = relation.source
          next if source.nil? || source.trashed?

          { "type" => source.record_type, "title" => usage_title(source), "field" => relation.field, "edit_url" => edit_url(source) }
        end.uniq { |item| [ item["type"], item["edit_url"] ] }
      end

      def usage_title(source)
        case source
        when Nibble::Records::GlobalSet then source.item&.[]("title") || source.handle.humanize
        when Nibble::Records::NavigationTree then source.handle.humanize
        else source.title.presence || "Untitled"
        end
      end

      def edit_url(source)
        case source
        when Nibble::Records::Entry then "/cp/collections/#{source.collection}/entries/#{source.id}/edit"
        when Nibble::Records::Term then "/cp/taxonomies/#{source.taxonomy}/terms/#{source.id}/edit"
        when Nibble::Records::GlobalSet then "/cp/globals/#{source.handle}/edit"
        when Nibble::Records::NavigationTree then "/cp/navigation/#{source.handle}/edit"
        end
      end
    end
  end
end
