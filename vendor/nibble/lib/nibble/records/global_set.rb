module Nibble
  module Records
    class GlobalSet < ::ApplicationRecord
      self.table_name = "global_sets"
      include Content

      def self.record_type = "global"

      belongs_to :origin, class_name: name, optional: true

      validate { errors.add(:handle, "isn't a global set in the schema") unless item }

      def item = Nibble.schema.find(:globals, handle)

      def blueprint_definition
        Blueprint.for(Schema::Item.new(kind: "blueprints", handle:, parent: item.key, path: item.path, layer: item.layer, data: item["blueprint"]))
      end

      def values = data.to_h
      def snapshot = values
      def assign_snapshot(snapshot) = self.data = snapshot.stringify_keys

      def event_payload = super.merge("handle" => handle)
    end
  end
end
