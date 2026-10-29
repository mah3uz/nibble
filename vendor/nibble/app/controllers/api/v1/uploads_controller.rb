module Api
  module V1
    # A file sent as the request body, held for upload_asset, so no file has to travel inside an operation's input.
    class UploadsController < OperationsController
      def update
        Nibble::Operations.require!(grant_principal(@grant), "assets.upload")
        filename = request.query_parameters["filename"].to_s
        length = request.get_header("CONTENT_LENGTH").to_s
        return problem(:length_required, "length_required", "Send the file's size in Content-Length.") unless length.match?(/\A\d+\z/)
        return problem(:bad_request, "empty", "Send the file as the request body.") if length.to_i.zero?
        return problem(:unsupported_media_type, "unsupported_type", Nibble::Assets::Upload.refusal(filename, 0)) unless Nibble::Assets.uploadable?(filename)

        limit = Nibble.config.max_upload_bytes
        blob = (Nibble::Assets::Staged.store(request.body, filename:, grant: @grant) if length.to_i <= limit)
        return problem(:content_too_large, "too_large", "#{filename} is larger than #{limit / 1.megabyte} MB.") unless blob

        render status: :created, json: { "data" => { "upload" => Nibble::Assets::Staged.id(blob), "filename" => blob.filename.to_s, "size" => blob.byte_size,
                                                     "expires_at" => Nibble::Assets::Staged.expires_at(blob).utc.iso8601 }, "meta" => meta }
      end

      private

      # The body is the file, whatever its Content-Type says, so it is never parsed as parameters.
      def process_action(...)
        request.request_parameters = {}
        super
      end

      def refuse_query_tokens
        return unless request.query_parameters.key?("access_token")

        problem(:bad_request, "invalid_request", "Send the token in the Authorization header, never in the URL.")
      end

      def authenticate
        token = request.query_parameters["upload_token"]
        return super if token.nil?
        return head(:not_found) unless Nibble::AgentAccess.enabled?

        @grant = Nibble::Assets::Staged.grant_for(token)
        problem(:unauthorized, "unauthorized", "This upload URL has expired or isn't valid.", hint: "Ask create_upload for a new one.") unless @grant
      end
    end
  end
end
