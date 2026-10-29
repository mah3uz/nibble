module Nibble
  module Assets
    # A file an app sent ahead of upload_asset: a blob with no asset and no address, usable only by the grant that sent it.
    module Staged
      LIFETIME = 1.day
      URL_LIFETIME = 15.minutes
      PURPOSE = :nibble_upload
      URL_PURPOSE = :nibble_upload_url

      module_function

      def store(io, filename:, grant:)
        limit = Nibble.config.max_upload_bytes
        Tempfile.create("nibble-upload", binmode: true) do |file|
          IO.copy_stream(io, file, limit + 1)
          return nil if file.size > limit

          file.rewind
          ActiveStorage::Blob.create_and_upload!(io: file, filename:, metadata: { "staged" => true, "grant_id" => grant.id })
        end
      end

      def id(blob) = blob.signed_id(purpose: PURPOSE, expires_at: expires_at(blob))

      def expires_at(blob) = blob.created_at + LIFETIME

      def find(id, grant)
        blob = ActiveStorage::Blob.find_signed(id.to_s, purpose: PURPOSE)
        blob if grant && staged?(blob) && blob.metadata["grant_id"] == grant.id
      end

      def find_for(id, user)
        blob = ActiveStorage::Blob.find_signed(id.to_s, purpose: PURPOSE)
        blob if staged?(blob) && Nibble::Grant.exists?(id: blob.metadata["grant_id"], user_id: user&.id)
      end

      def staged?(blob) = blob&.metadata&.dig("staged") == true

      def claim(blob) = blob.update!(metadata: blob.metadata.except("staged", "grant_id"))

      def release(blob, grant)
        blob.update!(metadata: blob.metadata.merge("staged" => true, "grant_id" => grant.id)) if ActiveStorage::Blob.exists?(blob.id)
      end

      def upload_url(site, grant, filename)
        token = grant.signed_id(purpose: URL_PURPOSE, expires_in: URL_LIFETIME)
        "#{site}/api/v1/uploads?#{{ filename:, upload_token: token }.to_query}"
      end

      def grant_for(token) = Nibble::Grant.active.find_signed(token.to_s, purpose: URL_PURPOSE)

      def purge_expired(now = Time.current)
        Assets.stray_blobs(before: now - LIFETIME).find_each { |blob| blob.purge if staged?(blob) }
      end
    end
  end
end
