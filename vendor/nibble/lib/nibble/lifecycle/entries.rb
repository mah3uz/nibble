module Nibble
  class Lifecycle
    class Entries < Handler
      ACTIONS = %w[create save publish unpublish submit approve reject trash restore revert discard_draft go_live expire move assign_terms replace_asset].freeze
      PUBLISHABLE = { "simple" => nil, "review" => %w[approved scheduled] }.freeze

      def initialize(...)
        super
        @previous_uri = record.uri
        @was_live = record.live?
      end

      def create
        collection = record.collection_item or invalid!(:collection, "isn't in the schema")
        record.blueprint ||= Array(collection["blueprints"]).first
        invalid!(:blueprint, "isn't a blueprint of the #{record.collection} collection") unless record.blueprint_item
        record.locale ||= Nibble.config.default_locale.code
        record.status = "draft"
        record.created_by_id = actor&.id
        record.author_id ||= actor&.id

        apply!(with_slug(incoming({})), full: false)
        revision!(:save)
        emit("record.created", "changes" => diff({}, record.snapshot))
      end

      def save(kind: :save, event: "record.saved")
        if record.live?
          save_draft(kind, event)
        else
          before = record.snapshot
          record.status = "draft" if record.status == "approved"
          apply!(with_slug(incoming(before)), full: false)
          revision!(kind)
          emit(event, "changes" => diff(before, record.snapshot))
        end
      end

      def move
        invalid!(:parent_id, "only entries in a structured collection can be moved") unless record.structured?
        before = record.snapshot
        record.parent_id = attrs["parent_id"].presence&.to_i
        record.position = attrs["position"].to_i if attrs.key?("position")
        record.uri = Uris.for(record)
        invalid!(:parent_id, record.errors[:parent].first || record.errors.full_messages.first) unless record.save

        # A pending draft keeps its own copy of the structure; publishing it would move the entry back.
        record.draft&.update!(data: record.draft.data.merge("parent_id" => record.parent_id, "position" => record.position))
        emit("record.moved", "changes" => diff(before, record.snapshot))
      end

      def assign_terms
        handle = attrs["field"].to_s
        field = record.blueprint_fields.get(handle)
        invalid!(:field, "isn't a taxonomy field on this entry") unless field&.type == "terms"
        ids = Array(attrs["term_ids"]).map(&:to_s).compact_blank
        invalid!(:term_ids, "choose at least one term") if ids.empty?

        merged = ->(current) { field.get("max_items").to_i == 1 ? ids.first : Array.wrap(current).map(&:to_s) | ids }
        unless record.live? && record.workflow == "simple"
          @attrs = { handle => merged.call((record.draft&.data || record.snapshot)[handle]) }
          return save
        end

        before = record.snapshot
        apply!(before.merge(handle => merged.call(before[handle])), full: false)
        record.draft&.update!(data: record.draft.data.merge(handle => merged.call(record.draft.data[handle])))
        revision!(:save)
        emit("record.saved", "changes" => diff(before, record.snapshot))
      end

      def replace_asset
        from, to = replaced_assets
        before = record.snapshot
        apply!(Nibble::Assets.swap(before, from, to), full: false)
        record.draft&.update!(data: Nibble::Assets.swap(record.draft.data, from, to))
        revision!(:save)
        emit("record.saved", "changes" => diff(before, record.snapshot))
      end

      def revert
        @attrs = attrs.merge(reverted_attrs)
        save(kind: :restore, event: "record.reverted")
      end

      def publish
        before = record.snapshot
        snapshot = with_slug(incoming(record.draft&.data || before))
        return if @was_live && record.draft.nil? && snapshot == before

        allowed = PUBLISHABLE.fetch(record.workflow)
        invalid!(:base, "This entry needs approval before it can be published.") if allowed && !allowed.include?(workflow_state)

        snapshot["published_at"] = Time.current.utc.iso8601 if snapshot["published_at"].blank?
        published_at = parse_time(snapshot["published_at"]) or invalid!(:published_at, "isn't a valid date")
        check_expiry!(snapshot, published_at)
        future = published_at > Time.current
        invalid!(:published_at, "can't be in the future while the entry is live; unpublish it first") if @was_live && future

        from = record.status
        record.status = future ? "scheduled" : "published"
        apply!(snapshot, full: true)
        remove_draft!
        transition!(from, record.status)
        revision!(:publish)
        emit(future ? "record.scheduled" : "record.published", "changes" => diff(before, record.snapshot))
      end

      def unpublish
        invalid!(:base, "Only published or scheduled entries can be unpublished.") unless %w[published scheduled].include?(record.status)

        before = record.snapshot
        from = record.status
        if record.draft
          record.assign_snapshot(record.draft.data)
          record.uri = Uris.for(record)
          remove_draft!
        end
        record.status = "unpublished"
        record.updated_by_id = actor&.id
        record.save!
        transition!(from, "unpublished")
        revision!(:save)
        emit("record.unpublished", "changes" => diff(before, record.snapshot))
      end

      def go_live
        return unless record.status == "scheduled" && record.published_at&.<=(Time.current) && !record.trashed?

        record.status = "published"
        record.save!
        transition!("scheduled", "published")
        revision!(:publish)
        emit("record.published", "changes" => {})
      end

      def expire
        return unless record.live? && record.unpublish_at&.<=(Time.current)

        unpublish
      end

      def submit = move_workflow(%w[draft unpublished], "in_review")
      def approve = move_workflow(%w[in_review], "approved")
      def reject = move_workflow(%w[in_review], "draft")

      def trash
        invalid!(:base, "Move or trash its child entries first.") if record.children.kept.exists?

        trash_record!
      end

      def restore
        invalid!(:base, "This entry isn't in the trash.") unless record.trashed?
        invalid!(:parent, "is in the trash; restore it first") if record.parent&.trashed?

        from = record.status
        record.deleted_at = nil
        record.status = "unpublished" if %w[published scheduled].include?(from)
        record.save!
        transition!(from, record.status)
        emit("record.restored")
      end

      def discard_draft
        invalid!(:base, "There is no draft to discard.") unless record.draft

        remove_draft!
        touch!
        emit("record.draft_discarded")
      end

      private

      def column_keys = Records::Entry::COLUMNS

      def workflow_state
        return record.status unless record.live?

        record.draft ? record.draft.workflow_status || "draft" : "published"
      end

      def with_slug(snapshot)
        snapshot["slug"] = snapshot["title"].to_s.parameterize.presence if snapshot["slug"].blank?
        snapshot
      end

      def apply!(snapshot, full:)
        validate_fields!(snapshot, full:)
        record.assign_snapshot(stored(snapshot))
        record.uri = Uris.for(record)
        record.updated_by_id = actor&.id
        record.save!
      end

      def save_draft(kind, event)
        base = record.draft&.data || record.snapshot
        snapshot = with_slug(incoming(base))
        validate_fields!(snapshot, full: false)
        data = stored(snapshot)
        check_columns!(data)

        draft = record.draft || record.build_draft
        workflow = draft.workflow_status == "approved" ? nil : draft.workflow_status
        draft.update!(data:, workflow_status: workflow, author_id: actor&.id)
        touch!
        revision!(kind, data)
        emit(event, "draft" => true, "changes" => diff(base, data))
      end

      def check_columns!(data)
        record.assign_snapshot(data)
        record.uri = Uris.for(record)
        valid = record.valid?
        errors = record.errors.to_hash(true).transform_keys(&:to_s)
        record.restore_attributes
        raise Invalid.new(errors) unless valid
      end

      def check_expiry!(snapshot, published_at)
        return if snapshot["unpublish_at"].blank?

        invalid!(:unpublish_at, "isn't used by this collection") unless record.expires?
        unpublish_at = parse_time(snapshot["unpublish_at"])
        invalid!(:unpublish_at, "must be after the publish date") unless unpublish_at && unpublish_at > published_at
      end

      def parse_time(value)
        value.respond_to?(:in_time_zone) && !value.is_a?(String) ? value.in_time_zone : Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def move_workflow(from_states, to)
        invalid!(:base, "The #{record.collection} collection doesn't use the review workflow.") unless record.workflow == "review"

        from = workflow_state
        invalid!(:base, "An entry that is #{from.humanize(capitalize: false)} can't be moved to #{to.humanize(capitalize: false)}.") unless from_states.include?(from)

        if record.live?
          record.draft.update!(workflow_status: to)
          touch!
        else
          record.status = to
          record.updated_by_id = actor&.id
          record.save!(validate: false)
        end
        transition!(from, to, comment: attrs["comment"])
        emit("workflow.transitioned", "from" => from, "to" => to, "comment" => attrs["comment"])
      end

      def transition!(from, to, comment: nil)
        return if from == to

        Records::WorkflowTransition.create!(record:, from:, to:, actor_id: actor&.id, comment:, created_at: Time.current)
      end

      def remove_draft!
        record.draft&.destroy!
        record.association(:draft).reset
      end

      def touch!
        record.updated_by_id = actor&.id
        record.updated_at = Time.current
        record.save!(validate: false)
      end

      def emit(name, extra = {})
        super(name, { "uri" => record.uri, "previous_uri" => @previous_uri, "was_live" => @was_live }.merge(extra))
      end
    end
  end
end
