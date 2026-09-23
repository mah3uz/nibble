module Nibble
  module Records
    module Content
      extend ActiveSupport::Concern

      DEFAULT_REVISIONS_KEEP = 100

      included do
        has_one :draft, as: :record, class_name: "Nibble::Records::Draft", dependent: :delete
        has_many :revisions, -> { order(:number) }, as: :record, class_name: "Nibble::Records::Revision", dependent: :delete_all
        has_many :outgoing_relations, as: :source, class_name: "Nibble::Records::Relation", dependent: :delete_all

        validate :locale_is_configured
      end

      class_methods do
        def polymorphic_name = record_type
      end

      def record_type = self.class.record_type
      def blueprint_fields = blueprint_definition.fields
      def revisions_keep = DEFAULT_REVISIONS_KEEP
      def live? = true
      def trashed? = respond_to?(:deleted_at) && deleted_at.present?

      def referrers
        Relation.where(target_type: record_type, target_id: id).includes(:source)
          .reject { |relation| relation.source.nil? || relation.source.trashed? || relation.source == self }
      end

      def relation_rows = RecordValues.new(self).relations(values)

      def event_payload = { "type" => record_type, "id" => id, "locale" => locale }

      private

      def locale_is_configured
        errors.add(:locale, "isn't a configured locale") unless Nibble.config.locale(locale)
      end
    end
  end
end
