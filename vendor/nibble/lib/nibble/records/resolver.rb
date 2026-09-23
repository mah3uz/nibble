module Nibble
  module Records
    class Resolver
      def initialize(model, scope_key:, scope_column:)
        @model = model
        @scope_key = scope_key
        @scope_column = scope_column
      end

      def find(ids, scope: {})
        records = scoped(scope).where(id: ids.map(&:to_s)).index_by { |record| record.id.to_s }
        ids.filter_map { |id| records[id.to_s] && summary(records[id.to_s]) }
      end

      def search(query:, scope: {}, limit: 20)
        title = @model.arel_table[:title]
        scoped(scope).where(title.lower.matches("%#{@model.sanitize_sql_like(query.to_s.downcase)}%")).order(:title).limit(limit).map { |record| summary(record) }
      end

      def resolve(id)
        record = @model.where(deleted_at: nil).find_by(id:)
        record && { url: record.uri, title: record.title }
      end

      private

      def scoped(scope)
        allowed = Array(scope[@scope_key]).compact_blank
        relation = @model.where(deleted_at: nil)
        allowed.any? ? relation.where(@scope_column => allowed) : relation
      end

      def summary(record)
        {
          "id" => record.id.to_s, "title" => record.title, "url" => record.uri, @scope_column.to_s => record.public_send(@scope_column),
          "status" => record.respond_to?(:status) ? record.status : nil
        }.compact
      end
    end
  end
end
