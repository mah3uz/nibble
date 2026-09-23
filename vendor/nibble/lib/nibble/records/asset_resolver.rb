module Nibble
  module Records
    class AssetResolver
      def find(ids, scope: {})
        records = scoped(scope).where(id: ids.map(&:to_s)).index_by { |asset| asset.id.to_s }
        ids.filter_map { |id| records[id.to_s] && summary(records[id.to_s], scope) }
      end

      def search(query:, scope: {}, limit: 20)
        pattern = "%#{Asset.sanitize_sql_like(query.to_s.downcase)}%"
        table = Asset.arel_table
        scoped(scope).where(table[:title].lower.matches(pattern).or(table[:filename].lower.matches(pattern)))
          .order(created_at: :desc).limit(limit).map { |asset| summary(asset, scope) }
      end

      def resolve(id)
        asset = Asset.kept.find_by(id:)
        asset && { url: asset.url, title: asset.display_title }
      end

      def summary(asset, scope = {})
        preset = Array(scope["preset"]).first.presence
        preset = nil unless preset && Assets.preset(preset) && Assets.transformable?(asset)
        width, height = Assets.output_size(asset, preset)
        {
          "id" => asset.id.to_s, "title" => asset.display_title, "filename" => asset.filename, "kind" => asset.kind,
          "url" => asset.url(preset), "srcset" => preset && srcset(asset, preset), "thumbnail" => asset.thumbnail_url,
          "alt" => asset.alt, "width" => width, "height" => height,
          "focal" => asset.focal, "mime" => asset.mime,
          "size" => asset.size, "folder" => asset.folder, "edit_url" => "/admin/media?asset=#{asset.id}"
        }
      end

      private

      def srcset(asset, preset)
        widths = Array(Assets.preset(preset)["srcset"])
        widths.any? ? widths.map { |width| "#{asset.url(preset, width:)} #{width}w" }.join(", ") : nil
      end

      def scoped(scope)
        relation = Asset.kept
        folders = Array(scope["folder"]).compact_blank
        if folders.any?
          conditions = folders.map { |folder| Asset.arel_table[:folder].eq(folder).or(Asset.arel_table[:folder].matches("#{Asset.sanitize_sql_like(folder)}/%")) }
          relation = relation.where(conditions.reduce(:or))
        end
        types = Array(scope["allowed_types"]).compact_blank.map { |type| type.to_s.downcase.delete_prefix(".") }
        if types.any?
          relation = relation.where(types.map { |type| Asset.arel_table[:filename].lower.matches("%.#{Asset.sanitize_sql_like(type)}") }.reduce(:or))
        end
        relation
      end
    end
  end
end
