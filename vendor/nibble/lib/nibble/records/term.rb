module Nibble
  module Records
    class Term < Nibble::ApplicationRecord
      self.table_name = "terms"
      include Content

      def self.record_type = "term"

      belongs_to :origin, class_name: name, optional: true

      scope :kept, -> { where(deleted_at: nil) }

      before_validation { self.uuid ||= SecureRandom.uuid }

      validates :slug, presence: true, format: { with: Entry::SLUG, allow_nil: true }
      validate :taxonomy_and_blueprint_exist
      validate :slug_unique

      def taxonomy_item = Nibble.schema.taxonomy(taxonomy)
      def blueprint_item = taxonomy_item && Nibble.schema.blueprint(taxonomy_item, blueprint)
      def blueprint_definition = Blueprint.for(blueprint_item)
      def route = taxonomy_item["route"]

      def live? = deleted_at.nil?
      def values = data.to_h.merge("title" => title)
      def snapshot = values.merge("slug" => slug)

      def assign_snapshot(snapshot)
        snapshot = snapshot.stringify_keys
        self.slug = snapshot["slug"] if snapshot.key?("slug")
        self.title = snapshot["title"]
        self.data = snapshot.except("title", "slug")
      end

      def event_payload = super.merge("taxonomy" => taxonomy)

      private

      def taxonomy_and_blueprint_exist
        return errors.add(:taxonomy, "isn't in the schema") unless taxonomy_item

        errors.add(:blueprint, "isn't a blueprint of the #{taxonomy} taxonomy") unless Array(taxonomy_item["blueprints"]).include?(blueprint)
      end

      def slug_unique
        return if slug.nil? || deleted_at

        errors.add(:slug, "is already used by another term") if self.class.kept.where(taxonomy:, locale:, slug:).where.not(id:).exists?
      end

      ActiveSupport.run_load_hooks(:nibble_term, self)
    end
  end
end
