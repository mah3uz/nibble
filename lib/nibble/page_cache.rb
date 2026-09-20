module Nibble
  module PageCache
    Page = Data.define(:body, :content_type, :tags)

    class << self
      attr_writer :store

      def store = @store || Rails.cache

      def key(*parts) = Digest::SHA256.hexdigest([ *parts, Nibble.schema.digest, Nibble.config.theme, build_version ].to_json)

      def read(key)
        meta = store.read("nibble:page:meta:#{key}") or return nil
        versions = store.read_multi(*meta["tags"].map { |tag| version_key(tag) })
        return nil unless versions.size == meta["tags"].size

        page = store.read("nibble:page:html:#{key}:#{digest(meta['tags'], versions)}") or return nil
        Page.new(body: page["body"], content_type: page["content_type"], tags: meta["tags"])
      end

      def write(key, tags, body:, content_type:)
        tags = tags.uniq.sort
        versions = store.read_multi(*tags.map { |tag| version_key(tag) })
        tags.each do |tag|
          next if versions.key?(version_key(tag))

          versions[version_key(tag)] = next_version
          store.write(version_key(tag), versions[version_key(tag)])
        end
        store.write("nibble:page:meta:#{key}", { "tags" => tags })
        store.write("nibble:page:html:#{key}:#{digest(tags, versions)}", { "body" => body, "content_type" => content_type })
      end

      def purge(*tags) = tags.flatten.each { |tag| store.write(version_key(tag), next_version) }

      private

      def version_key(tag) = "nibble:tagv:#{tag}"
      def next_version = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
      def digest(tags, versions) = Digest::SHA256.hexdigest(tags.map { |tag| versions[version_key(tag)] }.join(","))
      def build_version = ENV["KAMAL_VERSION"].presence || Rails.application.config.x.try(:build_version).presence || "dev"
    end
  end
end
