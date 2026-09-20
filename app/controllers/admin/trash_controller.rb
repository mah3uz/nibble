module Admin
  class TrashController < BaseController
    def index
      authorize!("trash.view")
      render inertia: "admin/trash/Index", props: { items: entries + terms + assets }
    end

    def restore
      record = find_record
      authorize!(ability(record, "delete"), record)
      result = Nibble::Lifecycle.call(record, :restore, {}, actor: Current.user)
      return redirect_to(admin_trash_index_path, alert: result.errors.values.flatten.first) unless result.ok?

      redirect_to admin_trash_index_path, notice: "Restored."
    end

    def purge
      record = find_record
      authorize!(ability(record, "delete"), record)
      Nibble::Records::Relation.where(target_type: record.record_type, target_id: record.id).delete_all
      record.destroy!
      redirect_to admin_trash_index_path, notice: "Deleted for good."
    end

    private

    def find_record
      type, id = params[:id].split("-", 2)
      Nibble::Records.model(type).find(id)
    end

    def ability(record, action)
      case record
      when Nibble::Records::Entry then "entries.#{record.collection}.#{action}"
      when Nibble::Records::Term then "terms.#{record.taxonomy}.#{action}"
      else "assets.#{action}"
      end
    end

    def entries
      Nibble::Records::Entry.where.not(deleted_at: nil).order(deleted_at: :desc).filter_map do |entry|
        next unless Nibble::Access.can?(Current.user, "entries.#{entry.collection}.delete", entry)

        item(entry, "entry", entry.collection)
      end
    end

    def terms
      Nibble::Records::Term.where.not(deleted_at: nil).order(deleted_at: :desc).filter_map do |term|
        next unless Nibble::Access.can?(Current.user, "terms.#{term.taxonomy}.delete", term)

        item(term, "term", term.taxonomy)
      end
    end

    def assets
      return [] unless Nibble::Access.can?(Current.user, "assets.delete")

      Nibble::Records::Asset.where.not(deleted_at: nil).order(deleted_at: :desc).map do |asset|
        { id: "asset-#{asset.id}", type: "asset", group: asset.folder.presence || "assets", title: asset.filename, uri: nil,
          deleted_at: asset.deleted_at.utc.iso8601, referrers: asset.referrers.size }
      end
    end

    def item(record, type, group)
      { id: "#{type}-#{record.id}", type:, group:, title: record.title, uri: record.uri,
        deleted_at: record.deleted_at.utc.iso8601, referrers: record.referrers.size }
    end
  end
end
