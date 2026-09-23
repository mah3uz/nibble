module Nibble
  module Subscribers
    module Uris
      def self.call(_name, payload)
        return unless payload["type"] == "entry" && payload.key?("previous_uri") && payload["previous_uri"] != payload["uri"]

        entry = Records::Entry.find_by(id: payload["id"]) or return
        Records::Redirect.record_move(payload["previous_uri"], payload["uri"]) if payload["was_live"] && entry.live?
        ActiveRecord.after_all_transactions_commit { Jobs::CascadeUris.perform_later(entry.id) } if entry.children.kept.exists?
      end
    end
  end
end
