module Nibble
  class Lifecycle
    class Handler
      attr_reader :record, :attrs, :actor, :mode, :action

      def initialize(record, attrs, actor:, mode:, action:)
        @record = record
        @attrs = attrs
        @actor = actor
        @mode = mode
        @action = action
      end

      private

      def values = @values ||= RecordValues.new(record)
      def field_handles = record.blueprint_fields.handles
      def column_keys = []

      def incoming(base) = base.to_h.merge(attrs.slice(*field_handles, *column_keys))

      def validate_fields!(snapshot, full:)
        errors = values.validate(snapshot.slice(*field_handles), full:)
        raise Invalid.new(errors) if errors.any?
      end

      def stored(snapshot) = values.process(snapshot)

      def invalid!(key, message) = raise(Invalid.new(key.to_s => [ message ]))

      def revision!(kind, snapshot = record.snapshot)
        Revisions.write(record, mode.to_s.start_with?("import") ? :import : kind, snapshot:, actor:, message: attrs["message"])
      end

      def emit(name, extra = {})
        Events.publish(name, record.event_payload.merge("actor" => actor && { "type" => "user", "id" => actor.id },
          "ip" => Current.ip, "mode" => mode&.to_s).merge(extra))
      end

      def diff(before, after) = Revisions.diff(record, before, after)

      def reverted_attrs
        revision = record.revisions.find_by(id: attrs["revision_id"]) or invalid!(:revision_id, "isn't a revision of this record")
        revision.data.slice(*field_handles, *column_keys)
      end

      def replaced_assets
        %w[from to].map { |key| Records::Asset.kept.find_by(id: attrs[key]) or invalid!(key, "isn't an asset in the library") }
      end

      def trash_record!
        invalid!(:base, "This is already in the trash.") if record.trashed?
        referrers = record.referrers
        raise NeedsConfirmation.new(referrers) if referrers.any? && attrs["force"] != true

        record.deleted_at = Time.current
        record.save!(validate: false)
        emit("record.trashed")
      end
    end
  end
end
