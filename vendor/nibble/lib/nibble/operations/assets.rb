module Nibble
  module Operations
    module Assets
      WRITABLE = %w[title alt caption credit folder tags filename].freeze

      module_function

      def operations
        [
          Operation.new(name: "list_assets", title: "List assets", read_only: true, destructive: false, needs: %w[assets read],
            handler: method(:list), description: "Uploaded files, newest first. Put an image in rich text as ![alt](asset:ID).",
            input: Operations.schema(Operations.page_input("folder" => { "type" => "string", "description" => "A folder path, or empty for the top" },
                                                           "filename" => { "type" => "string", "description" => "Filenames starting with this" }))),
          Operation.new(name: "get_asset", title: "Read an asset", read_only: true, destructive: false, needs: %w[assets read],
            handler: method(:get), description: "One asset: its URL, size, alt text and other fields, and its lock_version.",
            input: Operations.schema({ "id" => { "type" => "integer" } }, %w[id])),
          Operation.new(name: "upload_asset", title: "Upload an asset", read_only: false, destructive: false, needs: %w[assets write],
            handler: method(:upload), consequential: true, description: "Upload a file, sent as base64. Only the file types this site accepts, up to its size limit.",
            input: Operations.schema({ "filename" => { "type" => "string" }, "content_base64" => { "type" => "string" },
                                       "folder" => { "type" => "string" }, "alt" => { "type" => "string" }, "title" => { "type" => "string" } },
              %w[filename content_base64], write: true)),
          Operation.new(name: "update_asset", title: "Change an asset", read_only: false, destructive: false, needs: %w[assets write],
            handler: method(:update), consequential: true, description: "Change an asset's alt text, title, caption, credit, folder, tags or filename.",
            input: Operations.schema({ "id" => { "type" => "integer" }, "lock_version" => { "type" => "integer" },
                                       "data" => { "type" => "object" } }, %w[id lock_version data], write: true)),
          Operation.new(name: "transition_asset", title: "Trash or restore an asset", read_only: false, destructive: true,
            needs: %w[assets write], handler: method(:transition), consequential: ->(input) { input["action"] == "trash" },
            description: "trash, or restore from the trash.",
            input: Operations.schema({ "id" => { "type" => "integer" }, "action" => { "type" => "string", "enum" => %w[trash restore] } },
              %w[id action], write: true))
        ]
      end

      def list(input, caller)
        Operations.require!(caller.principal, "assets.view")
        per_page = input["per_page"] || 20
        page = [ input["page"].to_i, 1 ].max
        scope = Records::Asset.kept.order(created_at: :desc)
        scope = scope.where(folder: input["folder"]) unless input["folder"].nil?
        scope = scope.where("filename LIKE ?", "#{Records::Asset.sanitize_sql_like(input['filename'])}%") if input["filename"].present?
        { "assets" => scope.offset((page - 1) * per_page).limit(per_page).map { |asset| summary(asset) },
          "page" => { "current_page" => page, "per_page" => per_page, "total" => scope.count } }
      end

      def get(input, caller)
        Operations.require!(caller.principal, "assets.view")
        view(find!(input["id"]))
      end

      def upload(input, caller)
        content = Base64.strict_decode64(input["content_base64"])
        limit = Nibble.config.max_upload_bytes
        raise Failure.new("too_large", "the file is larger than #{limit / 1.megabyte} MB", status: :content_too_large) if content.bytesize > limit

        Operations.require!(caller.principal, "assets.upload")
        blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(content), filename: input["filename"].to_s)
        result = Nibble::Assets::Upload.call(blob, { "folder" => input["folder"].to_s, "alt" => input["alt"], "title" => input["title"] }.compact,
          actor: caller.principal)
        raise Failure.new("invalid", result.errors.values.flatten.first.to_s, details: { "errors" => result.errors }) unless result.ok?

        view(result.record).merge("result" => "uploaded", "site" => caller.site)
      rescue ArgumentError
        raise Failure.new("invalid_input", "content_base64 isn't valid base64")
      end

      def update(input, caller)
        asset = find!(input["id"])
        attrs = Editable.incoming(asset.blueprint_fields, input["data"], columns: WRITABLE).merge("lock_version" => input["lock_version"])
        view(Operations.lifecycle!(asset, :save, attrs, caller).reload).merge("result" => "saved", "site" => caller.site)
      end

      def transition(input, caller)
        asset = find!(input["id"], trashed: input["action"] == "restore")
        view(Operations.lifecycle!(asset, input["action"], {}, caller).reload).merge("result" => input["action"], "site" => caller.site)
      end

      def summary(asset)
        { "id" => asset.id, "filename" => asset.filename, "folder" => asset.folder, "kind" => asset.kind, "url" => asset.url,
          "alt" => asset.alt, "width" => asset.width, "height" => asset.height }.compact
      end

      def view(asset)
        summary(asset).merge("lock_version" => asset.lock_version, "tags" => asset.tags, "size" => asset.blob&.byte_size,
          "trashed" => asset.trashed?, "data" => Editable.outgoing(asset.blueprint_fields, asset.values))
      end

      def find!(id, trashed: false)
        (trashed ? Records::Asset.all : Records::Asset.kept).find_by(id:) or Operations.not_found!("asset #{id}")
      end
    end
  end
end
