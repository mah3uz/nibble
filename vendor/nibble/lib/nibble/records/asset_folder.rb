module Nibble
  module Records
    class AssetFolder < Nibble::ApplicationRecord
      self.table_name = "asset_folders"

      PATH = %r{\A[a-z0-9_-]+(?:/[a-z0-9_-]+)*\z}

      belongs_to :parent, class_name: name, optional: true
      has_many :children, class_name: name, foreign_key: :parent_id, inverse_of: :parent

      validates :path, presence: true, uniqueness: true, format: { with: PATH }

      def self.ensure!(path)
        return if path.blank?

        segments = path.split("/")
        segments.each_index.reduce(nil) do |parent, index|
          find_or_create_by!(path: segments[..index].join("/")) { |folder| folder.parent = parent }
        end
      end

      def name = path.split("/").last
    end
  end
end
