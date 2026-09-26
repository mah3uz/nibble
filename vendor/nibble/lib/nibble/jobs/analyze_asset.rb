module Nibble
  module Jobs
    class AnalyzeAsset < Nibble::ApplicationJob
      queue_as :media

      def perform(asset)
        asset.blob.analyze unless asset.blob.analyzed?
        asset.sync_file
        asset.update_columns(asset.changes.transform_values(&:last)) if asset.changed?
      end
    end
  end
end
