module Nibble
  class Lifecycle
    class Navigation < Handler
      ACTIONS = %w[save revert].freeze

      def save(kind: :save, event: nil)
        created = record.new_record?
        before = record.snapshot
        record.assign_snapshot(before.merge(attrs.slice("tree")))
        record.save!
        revision!(kind)
        emit(event || (created ? "record.created" : "record.saved"), "changes" => diff(before, record.snapshot))
      end

      def revert
        @attrs = attrs.merge(reverted_attrs)
        save(kind: :restore, event: "record.reverted")
      end

      private

      def field_handles = %w[tree]
    end
  end
end
