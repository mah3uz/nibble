module Admin
  class BlueprintsController < BaseController
    def index
      render inertia: "admin/blueprints/Index", props: { rows: rows }
    end

    def show
      found = find_blueprint(params[:handle]) or raise ActiveRecord::RecordNotFound
      parent, item = found

      render inertia: "admin/blueprints/Show", props: {
        label: "#{parent['title']}: #{item['title']}",
        source: item.path.to_s.delete_prefix("#{Rails.root}/"),
        blueprint: Nibble::Blueprint.new(item, schema: Nibble.schema).to_publish_h
      }
    end

    private

    def parents = Nibble.schema.collections + Nibble.schema.taxonomies

    def rows
      parents.flat_map do |parent|
        Nibble.schema.blueprints_for(parent).map do |item|
          { handle: "#{parent.handle}.#{item.handle}", title: item["title"], parent: parent["title"], icon: parent["icon"],
            group: parent.kind == "collections" ? "Collections" : "Taxonomies", count: count_for(parent, item) }
        end
      end
    end

    def count_for(parent, item)
      # A folder's pages are its content, and the records it may have left behind are read by nothing.
      if parent["files"].present?
        Nibble::Files.index.of(parent.handle).count { |page| page.blueprint == item.handle }
      elsif parent.kind == "collections"
        Nibble::Records::Entry.kept.where(collection: parent.handle, blueprint: item.handle).count
      else
        Nibble::Records::Term.kept.where(taxonomy: parent.handle, blueprint: item.handle).count
      end
    end

    def find_blueprint(handle)
      parent_handle, blueprint_handle = handle.to_s.split(".", 2)
      parent = parents.find { |item| item.handle == parent_handle } or return nil
      item = Nibble.schema.blueprint(parent, blueprint_handle) or return nil

      [ parent, item ]
    end
  end
end
