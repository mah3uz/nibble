module Nibble
  module Subscribers
    module PageCache
      def self.call(_name, payload)
        return if payload["draft"]

        scope = payload["collection"] ? "collection:#{payload['collection']}" : payload["taxonomy"] && "taxonomy:#{payload['taxonomy']}"
        tag = %w[global navigation].include?(payload["type"]) ? "#{payload['type']}:#{payload['handle']}" : "#{payload['type']}:#{payload['id']}"
        Nibble::PageCache.purge([ tag, scope ].compact)
      end
    end
  end
end
