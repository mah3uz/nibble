module Nibble
  module Records
    class Entry < ::ApplicationRecord
      self.table_name = "entries"
      include Content

      STATUSES = %w[draft in_review approved scheduled published unpublished].freeze
      COLUMNS = %w[slug published_at unpublish_at parent_id position template author_id].freeze
      SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

      def self.record_type = "entry"

      belongs_to :parent, class_name: name, optional: true
      has_many :children, class_name: name, foreign_key: :parent_id, inverse_of: :parent
      belongs_to :origin, class_name: name, optional: true
      belongs_to :author, class_name: "::User", optional: true

      scope :kept, -> { where(deleted_at: nil) }
      scope :live, -> { kept.where(status: "published") }

      before_validation { self.uuid ||= SecureRandom.uuid }

      validates :status, inclusion: { in: STATUSES }
      validates :slug, format: { with: SLUG, allow_nil: true }
      validate :collection_and_blueprint_exist
      validate :slug_unique_among_siblings
      validate :uri_available
      validate :parent_valid

      def collection_item = Nibble.schema.collection(collection)
      def blueprint_item = collection_item && Nibble.schema.blueprint(collection_item, blueprint)
      def blueprint_definition = Blueprint.for(blueprint_item)

      def blueprint_fields
        fields = blueprint_definition.fields
        missing = Array(collection_item["taxonomies"]) - fields.handles
        return fields if missing.empty?

        extra = Fields.new(missing.map { |handle| { "handle" => handle, "field" => { "type" => "terms", "taxonomies" => [ handle ] } } },
                           schema: Nibble.schema, source: "#{collection} taxonomies")
        Fields.new(nil, schema: Nibble.schema, source: fields.source, fields: fields.all.merge(extra.all))
      end

      def workflow = collection_item["workflow"] || "simple"
      def dated? = collection_item["dated"] == true
      def expires? = collection_item["expires"] == true
      def structured? = collection_item["structure"].is_a?(Hash)
      def max_depth = structured? ? collection_item["structure"]["max_depth"] : nil
      def route = collection_item["route"]
      def revisions_keep = collection_item.data.dig("revisions", "keep") || DEFAULT_REVISIONS_KEEP

      def live? = status == "published" && deleted_at.nil?
      def depth = parent ? parent.depth + 1 : 1
      def home? = structured? && collection_item["structure"]["root"] == true && parent_id.nil? && slug == "home"

      def values = data.to_h.merge("title" => title)

      def snapshot
        values.merge(COLUMNS.index_with { |column| column_value(column) })
      end

      def assign_snapshot(snapshot)
        snapshot = snapshot.stringify_keys
        assign_attributes(snapshot.slice(*COLUMNS))
        self.title = snapshot["title"]
        self.data = snapshot.except("title", *COLUMNS)
      end

      def descendants = children.kept.flat_map { |child| [ child, *child.descendants ] }

      def event_payload = super.merge("collection" => collection)

      private

      def column_value(column)
        value = self[column]
        value.respond_to?(:iso8601) ? value.utc.iso8601 : value
      end

      def collection_and_blueprint_exist
        return errors.add(:collection, "isn't in the schema") unless collection_item

        errors.add(:blueprint, "isn't a blueprint of the #{collection} collection") unless Array(collection_item["blueprints"]).include?(blueprint)
      end

      def slug_unique_among_siblings
        return if slug.nil? || deleted_at || !collection_item

        siblings = self.class.kept.where(collection:, locale:, slug:, parent_id: structured? ? parent_id : nil).where.not(id:)
        errors.add(:slug, "is already used by another entry") if siblings.exists?
      end

      def uri_available
        return if uri.nil? || deleted_at

        errors.add(:uri, "#{uri} is already used by another entry") if self.class.kept.where(uri:).where.not(id:).exists?
        reserved = Nibble.config.reserved_paths.find { |path| uri == path || uri.start_with?("#{path}/") }
        errors.add(:uri, "#{uri} is reserved for #{reserved}") if reserved
      end

      def parent_valid
        return if parent_id.nil? || !collection_item
        return errors.add(:parent, "isn't allowed: #{collection} isn't a structured collection") unless structured?
        return errors.add(:parent, "must be an entry of the same collection and locale") unless parent && parent.collection == collection && parent.locale == locale
        return errors.add(:parent, "is in the trash") if parent.trashed?
        return errors.add(:parent, "can't be the entry itself or one of its descendants") if persisted? && (parent == self || descendants.include?(parent))

        errors.add(:parent, "is too deep (max depth #{max_depth})") if max_depth && depth > max_depth
      end

      ActiveSupport.run_load_hooks(:nibble_entry, self)
    end
  end
end
