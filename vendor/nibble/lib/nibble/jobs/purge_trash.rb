module Nibble
  module Jobs
    class PurgeTrash < Nibble::ApplicationJob
      queue_as :maintenance

      def perform(now: Time.current)
        cutoff = now - Nibble.config.trash_retention_days.days
        [ Records::Entry, Records::Term ].each do |model|
          model.where(deleted_at: ...cutoff).find_each do |record|
            model.transaction do
              model.where(origin_id: record.id).update_all(origin_id: nil)
              Records::Entry.where(parent_id: record.id).update_all(parent_id: nil) if model == Records::Entry
              Records::Relation.where(target_type: record.record_type, target_id: record.id).delete_all
              Records::WorkflowTransition.where(record_type: record.record_type, record_id: record.id).delete_all
              record.destroy!
            end
          end
        end
        Records::Asset.where(deleted_at: ...cutoff).find_each do |asset|
          Records::Asset.transaction do
            Records::Relation.where(target_type: "asset", target_id: asset.id).delete_all
            asset.destroy!
          end
        end
      end
    end
  end
end
