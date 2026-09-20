module Nibble
  module Subscribers
    module Relations
      def self.call(_name, payload)
        record = Records.model(payload["type"]).find_by(id: payload["id"]) or return

        rows = record.relation_rows.filter_map do |field, type, id, position|
          target_id = Integer(id.to_s, exception: false) or next
          { source_type: record.record_type, source_id: record.id, field:, locale: record.locale, target_type: type, target_id:, position: }
        end
        Records::Relation.where(source_type: record.record_type, source_id: record.id).delete_all
        Records::Relation.insert_all!(rows) if rows.any?
      end
    end
  end
end
