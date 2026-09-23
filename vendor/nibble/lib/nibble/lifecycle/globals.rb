module Nibble
  class Lifecycle
    class Globals < Handler
      ACTIONS = %w[save revert replace_asset].freeze

      def save(kind: :save, event: nil)
        invalid!(:handle, "isn't a global set in the schema") unless record.item

        created = record.new_record?
        before = record.snapshot
        snapshot = incoming(before)
        validate_fields!(snapshot, full: true)
        record.assign_snapshot(stored(snapshot))
        record.save!
        revision!(kind)
        emit(event || (created ? "record.created" : "record.saved"), "changes" => diff(before, record.snapshot))
      end

      def replace_asset
        from, to = replaced_assets
        @attrs = Nibble::Assets.swap(record.snapshot, from, to)
        save
      end

      def revert
        @attrs = attrs.merge(reverted_attrs)
        save(kind: :restore, event: "record.reverted")
      end
    end
  end
end
