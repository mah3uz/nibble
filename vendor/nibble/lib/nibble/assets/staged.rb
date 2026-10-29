module Nibble
  module Assets
    # A file an app sent ahead of upload_asset: a blob with no asset and no address, usable only by the grant that sent it.
    module Staged
      LIFETIME = 1.day
      URL_LIFETIME = 15.minutes
      PURPOSE = :nibble_upload
      URL_PURPOSE = :nibble_upload_url
      MARKERS = %w[staged grant_id].freeze

      module_function

      def store(io, filename:, grant:)
        limit = Nibble.config.max_upload_bytes
        Tempfile.create("nibble-upload", binmode: true) do |file|
          IO.copy_stream(io, file, limit + 1)
          return nil if file.size > limit

          file.rewind
          ActiveStorage::Blob.create_and_upload!(io: file, filename:,
            metadata: { "staged" => true, "grant_id" => grant.id, "expires_at" => LIFETIME.from_now.utc.iso8601 })
        end
      end

      def id(blob) = blob.signed_id(purpose: PURPOSE)

      def expires_at(blob) = Time.iso8601(blob.metadata["expires_at"].to_s)

      def expired?(blob, now = Time.current) = expires_at(blob) <= now

      def owned?(blob, grant) = !grant.nil? && blob.metadata["staged"] == true && blob.metadata["grant_id"] == grant.id

      def staged?(blob) = blob&.metadata&.dig("staged") == true

      # The blob, or why it can't be used: :expired once it has run out or been deleted, :not_found otherwise.
      def lookup(id, grant)
        blob_id = ActiveStorage::Blob.signed_id_verifier.verified(id.to_s, purpose: PURPOSE.to_s) or return :not_found
        blob = ActiveStorage::Blob.find_by(id: blob_id) or return :expired
        return :not_found unless owned?(blob, grant)

        expired?(blob) ? :expired : blob
      end

      def find(id, grant) = lookup(id, grant).then { |found| found if found.is_a?(ActiveStorage::Blob) }

      def find_for(id, user)
        blob = ActiveStorage::Blob.find_signed(id.to_s, purpose: PURPOSE)
        blob if staged?(blob) && !expired?(blob) && Nibble::Grant.exists?(id: blob.metadata["grant_id"], user_id: user&.id)
      end

      # Under a row lock, so of two requests holding the same upload only one makes an asset of it.
      def claim(blob, grant)
        blob.with_lock do
          next false unless owned?(blob, grant) && !expired?(blob)

          blob.update!(metadata: blob.metadata.except(*MARKERS))
        end
      end

      def release(blob, grant)
        return unless ActiveStorage::Blob.exists?(blob.id)

        blob.with_lock { blob.update!(metadata: blob.metadata.merge("staged" => true, "grant_id" => grant.id)) }
      end

      def keep_until(blob, time)
        blob.with_lock do
          next unless staged?(blob) && expires_at(blob) < time

          blob.update!(metadata: blob.metadata.merge("expires_at" => time.utc.iso8601))
        end
      end

      def upload_url(site, grant, filename)
        token = grant.signed_id(purpose: URL_PURPOSE, expires_in: URL_LIFETIME)
        "#{site}/api/v1/uploads?#{{ filename:, upload_token: token }.to_query}"
      end

      def grant_for(token) = Nibble::Grant.active.find_signed(token.to_s, purpose: URL_PURPOSE)

      def purge_expired(now = Time.current)
        Assets.stray_blobs(before: now - LIFETIME).find_each { |blob| blob.purge if staged?(blob) && expired?(blob, now) }
      end
    end
  end
end
