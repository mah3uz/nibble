module Nibble
  class Presenter
    class Preload
      MODELS = { "entry" => Records::Entry, "term" => Records::Term, "asset" => Records::Asset }.freeze

      class Resolver
        def initialize(preload, type)
          @preload = preload
          @type = type
        end

        def find(ids, scope: {})
          ids.filter_map do |id|
            record = @preload.record(@type, id) or next
            next unless in_scope?(record, scope)

            Dependencies.add("#{@type}:#{record.id}")
            @preload.summary(record)
          end
        end

        def resolve(id)
          record = @preload.record(@type, id) or return nil
          Dependencies.add("#{@type}:#{record.id}")
          { url: record.uri, title: record.title }
        end

        def search(**) = []

        private

        def in_scope?(record, scope)
          column = @type == "entry" ? "collections" : "taxonomies"
          allowed = Array(scope[column]).compact_blank
          allowed.empty? || allowed.include?(@type == "entry" ? record.collection : record.taxonomy)
        end
      end

      class AssetResolver
        def initialize(preload, fallback)
          @preload = preload
          @fallback = fallback
        end

        def find(ids, scope: {})
          missing = ids.reject { |id| @preload.record("asset", id) }
          fetched = missing.any? ? @fallback.find(missing, scope:).index_by { |summary| summary["id"] } : {}
          ids.filter_map do |id|
            asset = @preload.record("asset", id)
            next fetched[id.to_s] unless asset

            @fallback.summary(asset, scope) if in_scope?(asset, scope)
          end
        end

        def resolve(id)
          asset = @preload.record("asset", id) or return @fallback.resolve(id)
          { url: asset.url, title: asset.display_title }
        end

        def summary(asset, scope = {}) = @fallback.summary(asset, scope)
        def search(**) = []

        private

        def in_scope?(asset, scope)
          folders = Array(scope["folder"]).compact_blank
          types = Array(scope["allowed_types"]).compact_blank.map { |type| type.to_s.downcase.delete_prefix(".") }
          (folders.empty? || folders.any? { |folder| asset.folder == folder || asset.folder.start_with?("#{folder}/") }) &&
            (types.empty? || types.include?(asset.filename.to_s.downcase.split(".").last))
        end
      end

      def initialize(context:)
        @context = context
        @records = Hash.new { |hash, type| hash[type] = {} }
        @loaded_sources = Set.new
      end

      def resolvers
        %w[entry term].to_h { |type| [ type, Resolver.new(self, type) ] }
          .merge("asset" => AssetResolver.new(self, Resolvers.find("asset")))
      end

      def load(sources)
        pending = sources.reject { |source| @loaded_sources.include?([ source.record_type, source.id ]) }
        pending.each { |source| @loaded_sources << [ source.record_type, source.id ] }
        return if pending.empty?

        conditions = pending.group_by(&:record_type).map { |type, list| Records::Relation.where(source_type: type, source_id: list.map(&:id)) }
        rows = conditions.reduce(:or).pluck(:target_type, :target_id)
        rows.group_by(&:first).each do |type, pairs|
          model = MODELS[type] or next
          ids = pairs.map(&:last).uniq - @records[type].keys
          next if ids.empty?

          scope = model.where(id: ids, deleted_at: nil)
          scope = scope.where(status: "published") if type == "entry" && @context.public?
          scope.each { |record| @records[type][record.id] = record }
        end
      end

      def record(type, id)
        number = Integer(id.to_s, exception: false) or return nil
        @records[type.to_s][number]
      end

      def summary(record)
        scope = record.respond_to?(:collection) ? { "collection" => record.collection } : { "taxonomy" => record.taxonomy }
        { "id" => record.id.to_s, "type" => record.record_type, "title" => record.title, "uri" => record.uri, "url" => Presenter.url(record.uri) }.merge(scope)
      end
    end
  end
end
