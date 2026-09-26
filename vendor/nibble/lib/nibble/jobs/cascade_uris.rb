module Nibble
  module Jobs
    class CascadeUris < Nibble::ApplicationJob
      queue_as :events

      def perform(entry_id)
        entry = Records::Entry.find_by(id: entry_id) or return

        Records::Entry.transaction do
          moved = entry.descendants.count do |child|
            uri = Nibble::Uris.for(child)
            next false if uri == child.uri

            previous = child.uri
            child.update_columns(uri:, updated_at: Time.current)
            Records::Redirect.record_move(previous, uri) if child.live?
            true
          end
          Events.publish("record.uris_changed", entry.event_payload.merge("count" => moved)) if moved.positive?
        end
      end
    end
  end
end
