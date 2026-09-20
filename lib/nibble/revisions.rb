module Nibble
  module Revisions
    class << self
      def write(record, kind, snapshot:, actor:, message: nil)
        last = record.revisions.reorder(number: :desc).first
        revision = record.revisions.create!(kind: kind.to_s, data: snapshot, actor_id: actor&.id, message:, created_at: Time.current,
          number: (last&.number || 0) + 1)
        prune(record)
        revision
      end

      def diff(record, from, to)
        from = from.to_h
        to = to.to_h
        fields = record.blueprint_fields
        (from.keys | to.keys).each_with_object({}) do |key, changes|
          field = fields.get(key)
          change = field ? field.fieldtype.diff(from[key], to[key]) : Fieldtype.new.diff(from[key], to[key])
          changes[key] = change if change
        end
      end

      private

      def prune(record)
        stale = record.revisions.reorder(number: :desc).offset(record.revisions_keep).pluck(:id)
        Records::Revision.where(id: stale).delete_all if stale.any?
      end
    end
  end
end
