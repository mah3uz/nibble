module Nibble
  class Lifecycle
    class Terms < Handler
      ACTIONS = %w[create save trash restore revert replace_asset].freeze

      def create
        taxonomy = record.taxonomy_item or invalid!(:taxonomy, "isn't in the schema")
        record.blueprint ||= Array(taxonomy["blueprints"]).first
        invalid!(:blueprint, "isn't a blueprint of the #{record.taxonomy} taxonomy") unless record.blueprint_item
        record.locale ||= Nibble.config.default_locale.code

        apply!(incoming({}))
        revision!(:save)
        emit("record.created", "changes" => diff({}, record.snapshot))
      end

      def save(kind: :save, event: "record.saved")
        before = record.snapshot
        apply!(incoming(before))
        revision!(kind)
        emit(event, "changes" => diff(before, record.snapshot))
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

      def trash = trash_record!

      def restore
        invalid!(:base, "This term isn't in the trash.") unless record.trashed?

        record.deleted_at = nil
        record.save!
        emit("record.restored")
      end

      private

      def column_keys = %w[slug]

      def apply!(snapshot)
        snapshot["slug"] = snapshot["title"].to_s.parameterize.presence if snapshot["slug"].blank?
        validate_fields!(snapshot, full: true)
        record.assign_snapshot(stored(snapshot))
        record.uri = Uris.for(record)
        record.save!
      end
    end
  end
end
