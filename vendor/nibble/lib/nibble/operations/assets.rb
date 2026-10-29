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
          Operation.new(name: "create_upload", title: "Get an upload URL", read_only: false, destructive: false, needs: %w[assets write],
            handler: method(:create_upload),
            description: "A URL to send one file to with an HTTP PUT, the file's bytes as the body (curl -T file 'URL'). The answer's " \
                         "upload id goes to upload_asset as upload. Use this for a file you have locally instead of content_base64.",
            input: Operations.schema({ "filename" => { "type" => "string", "description" => "The file's name, with its extension" } }, %w[filename])),
          Operation.new(name: "upload_asset", title: "Upload an asset", read_only: false, destructive: false, needs: %w[assets write],
            handler: method(:upload), consequential: true, held: method(:held),
            description: "Make an asset from exactly one of: upload (an id from sending a file to create_upload's URL), url (a public " \
                         "web address the site fetches), or content_base64 (only for small files; it needs filename). Only the file " \
                         "types this site accepts, up to its size limit.",
            input: Operations.schema({ "upload" => { "type" => "string", "description" => "An upload id from create_upload's URL" },
                                       "url" => { "type" => "string", "description" => "An http or https address to fetch the file from" },
                                       "content_base64" => { "type" => "string" },
                                       "filename" => { "type" => "string", "description" => "Required with content_base64; names a url's file" },
                                       "folder" => { "type" => "string" }, "alt" => { "type" => "string" }, "title" => { "type" => "string" } },
              [], write: true)),
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

      def create_upload(input, caller)
        Operations.require!(caller.principal, "assets.upload")
        grant = caller.principal.grant or raise Failure.new("forbidden", "only a connected app can send files this way", status: :forbidden)
        uploadable!(input["filename"])

        { "url" => Nibble::Assets::Staged.upload_url(caller.site, grant, input["filename"]), "method" => "PUT",
          "max_bytes" => Nibble.config.max_upload_bytes, "accepted_types" => (Nibble::Assets::UPLOADABLE + Nibble.config.asset_extensions).uniq.sort,
          "expires_in" => Nibble::Assets::Staged::URL_LIFETIME.to_i }
      end

      def upload(input, caller)
        source = source!(input)
        Operations.require!(caller.principal, "assets.upload")
        attrs = { "folder" => input["folder"].to_s, "alt" => input["alt"], "title" => input["title"] }.compact
        result = source == "upload" ? from_upload(input, attrs, caller) : Nibble::Assets::Upload.call(new_blob(input), attrs, actor: caller.principal)
        raise Failure.new("invalid", result.errors.values.flatten.first.to_s, details: { "errors" => result.errors }) unless result.ok?

        view(result.record).merge("result" => "uploaded", "site" => caller.site)
      end

      # Waiting for approval, the file is fetched or decoded once and held as an upload, so what the person sees is what is made.
      def held(input, caller)
        source = source!(input)
        Operations.require!(caller.principal, "assets.upload")
        grant = caller.principal.grant
        if source == "upload"
          blob = staged!(input["upload"], grant)
        else
          sent = file(input)
          blob = Nibble::Assets::Staged.store(sent[:io], filename: sent[:filename], grant:)
          input = input.except("url", "content_base64", "filename").merge("upload" => Nibble::Assets::Staged.id(blob))
        end
        Nibble::Assets::Staged.keep_until(blob, (Nibble::Approval::LIFETIME + 1.hour).from_now)
        input
      end

      def source!(input)
        sources = %w[upload url content_base64].select { |key| input.key?(key) }
        return sources.first if sources.one?

        raise Failure.new("invalid_input", "send exactly one of upload, url or content_base64",
          hint: "Send a local file to create_upload's URL and pass its upload id, or pass a url the site can fetch.")
      end

      def from_upload(input, attrs, caller)
        raise Failure.new("invalid_input", "an upload keeps the filename it was sent with; leave filename out") if input.key?("filename")

        grant = caller.principal.grant
        blob = staged!(input["upload"], grant)
        unless Nibble::Assets::Staged.claim(blob, grant)
          raise Failure.new("upload_in_use", "another request is making an asset of this upload", status: :conflict,
            hint: "list_assets shows it once that request is done.")
        end

        Nibble::Assets::Upload.call(blob, attrs, actor: caller.principal).tap do |result|
          Nibble::Assets::Staged.release(blob, grant) unless result.ok?
        end
      end

      def staged!(id, grant)
        found = Nibble::Assets::Staged.lookup(id, grant)
        return found if found.is_a?(ActiveStorage::Blob)

        if found == :expired
          raise Failure.new("upload_expired", "that upload has expired, and its file is gone", status: :gone,
            hint: "Send the file again with a new create_upload URL.")
        end
        raise Failure.new("upload_not_found", "that upload was used already, or wasn't sent by this connection", status: :not_found,
          hint: "Send the file again with a new create_upload URL.")
      end

      def new_blob(input) = ActiveStorage::Blob.create_and_upload!(**file(input))

      def file(input)
        input.key?("url") ? fetched(input["url"], input["filename"]) : decoded(input["content_base64"], input["filename"])
      end

      def decoded(content_base64, filename)
        raise Failure.new("invalid_input", "missing filename", hint: "content_base64 needs a filename.") if filename.blank?

        content = Base64.strict_decode64(content_base64)
        limit = Nibble.config.max_upload_bytes
        raise Failure.new("too_large", "the file is larger than #{limit / 1.megabyte} MB", status: :content_too_large) if content.bytesize > limit

        { io: StringIO.new(content), filename: }
      rescue ArgumentError
        raise Failure.new("invalid_input", "content_base64 isn't valid base64")
      end

      def fetched(url, filename)
        filename = filename.presence || File.basename(URI.parse(url).path.to_s)
        uploadable!(filename, hint: "Name the file, with its extension, in filename.")
        response = Outbound.request(:get, url, purpose: "asset_upload", headers: { "Accept" => "*/*" }, timeout: 30,
          max_bytes: Nibble.config.max_upload_bytes)
        raise Failure.new("fetch_failed", "#{url} answered #{response.status}") unless response.ok?

        { io: StringIO.new(response.body), filename: }
      rescue URI::InvalidURIError, Outbound::Refused, Outbound::Failed => error
        raise Failure.new("fetch_failed", "the site couldn't fetch #{url}: #{error.message}",
          hint: "Use a public http or https address, or send the file to create_upload's URL instead.")
      end

      def uploadable!(filename, hint: nil)
        message = Nibble::Assets::Upload.refusal(filename, 0) or return
        raise Failure.new("invalid", message, hint:)
      end

      def update(input, caller)
        asset = find!(input["id"])
        attrs = Editable.incoming(asset.blueprint_fields, input["data"], columns: WRITABLE).merge("lock_version" => input["lock_version"])
        result = Operations.change!(asset, :save, attrs, caller)
        view(result.record.reload).merge("result" => "saved", "site" => caller.site, **Operations.ignored(result))
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
