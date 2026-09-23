module Nibble
  module Subscribers
    module Search
      def self.call(_name, payload)
        return if payload["draft"] || !%w[entry term].include?(payload["type"])

        record = Records.model(payload["type"]).find_by(id: payload["id"]) or return
        Nibble::Search.index_record(record)
      end
    end
  end
end
