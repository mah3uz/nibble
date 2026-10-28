class NibblePickShareImagesFromLibrary < ActiveRecord::Migration[8.1]
  TABLES = %w[entries terms drafts revisions global_sets].freeze
  MEDIA_URL = %r{/media/([0-9a-f-]{36})/}
  SEO_KEYS = %w[title exact_title description canonical og_image noindex nositemap schema_type json_ld_overrides].freeze

  def up
    assets = select_rows("SELECT uuid, id FROM assets WHERE deleted_at IS NULL").to_h
    dropped = []
    TABLES.each do |table|
      select_rows("SELECT id, data FROM #{table}").each do |id, raw|
        data = raw.is_a?(String) ? JSON.parse(raw) : raw
        changed = false
        data.each_value do |field|
          convert(field) do |value|
            changed = true
            asset = assets[value[MEDIA_URL, 1]]
            dropped << "#{table} ##{id}: #{value}" if !asset && value.present?
            asset && { "asset" => asset.to_s }
          end
        end
        execute "UPDATE #{table} SET data = #{quote(data.to_json)} WHERE id = #{id.to_i}" if changed
      end
    end
    say "Share images that are not library assets were removed; pick them again:" if dropped.any?
    dropped.each { |line| say line, true }
  end

  def down = raise(ActiveRecord::IrreversibleMigration)

  private

  def convert(node, &block)
    case node
    when Hash
      if node["og_image"].is_a?(String) && (node.keys - SEO_KEYS).empty?
        replacement = block.call(node["og_image"])
        replacement ? node["og_image"] = replacement : node.delete("og_image")
      end
      node.each_value { |child| convert(child, &block) }
    when Array
      node.each { |child| convert(child, &block) }
    end
  end
end
