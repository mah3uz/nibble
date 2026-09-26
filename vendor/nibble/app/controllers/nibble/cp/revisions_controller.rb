module Nibble
  module Cp
    class RevisionsController < BaseController
      PER_PAGE = 20
      LABELS = { "save" => "Saved", "publish" => "Published", "restore" => "Restored", "import" => "Imported" }.freeze

      before_action :load_entry

      def index
        authorize!(ability("view"))
        page = [ params[:page].to_i, 1 ].max
        all = @entry.revisions.reorder(number: :desc).includes(:actor)
        revisions = all.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a

        render json: {
          record: { id: @entry.id, type: "entry", title: @entry.title, path: @entry.uri, lock_version: @entry.lock_version, live: @entry.live? },
          versions: revisions.map { |revision| version(revision) },
          pagination: { page:, per_page: PER_PAGE, total: all.count, pages: [ (all.count / PER_PAGE.to_f).ceil, 1 ].max }
        }
      end

      def restore
        authorize!(ability("edit"), @entry)
        result = Nibble::Lifecycle.call(@entry, :revert, { "revision_id" => params[:id], "lock_version" => params[:lock_version] }, actor: Nibble::Current.user)
        return redirect_back_or_to(edit_path, inertia: { errors: result.errors.transform_values { |messages| Array(messages).first } }) unless result.ok?

        redirect_to edit_path, notice: "Revision restored."
      end

      private

      def version(revision)
        previous = @entry.revisions.where(number: ...revision.number).reorder(number: :desc).first
        {
          id: revision.id, label: LABELS.fetch(revision.kind, revision.kind.humanize), created_at: revision.created_at.utc.iso8601,
          author: revision.actor&.name, restorable: true, message: revision.message,
          changes: Nibble::Revisions.diff(@entry, previous&.data || {}, revision.data).transform_values { |change| [ change["from"], change["to"] ] }
        }
      end

      def load_entry
        @collection = Nibble.schema.collection(params[:handle]) or raise ActiveRecord::RecordNotFound
        @entry = Nibble::Records::Entry.where(collection: @collection.handle).find(params[:entry_id])
      end

      def ability(action) = "entries.#{@collection.handle}.#{action}"
      def edit_path = edit_cp_collection_entry_path(@collection.handle, @entry)
    end
  end
end
