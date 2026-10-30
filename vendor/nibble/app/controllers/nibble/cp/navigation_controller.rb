module Nibble
  module Cp
    class NavigationController < BaseController
      def index
        menus = Nibble.schema.navigations.select { |item| Nibble::Access.can?(Nibble::Current.user, "navigation.#{item.handle}.edit") }
        raise NotAuthorized if menus.empty?

        render inertia: "cp/navigation/Index", props: {
          menus: menus.map { |item| { handle: item.handle, title: item["title"], url: "/cp/navigation/#{item.handle}/edit" } }
        }
      end

      def edit
        item = load_item
        return render_files_menu(item) if (folder = files_folder(item))

        tree = record(item)
        render inertia: "cp/navigation/Edit", props: {
          menu: menu(item, tree.locale).merge(item_fields: tree.item_fields.to_publish_a),
          tree: to_tree_items(tree.tree.to_a, tree.item_fields),
          records: linkable(item),
          assets: Nibble::Resolvers.find("asset").find(tree.links.select { |node| node["type"] == "asset" }.map { |node| node["id"].to_s }.uniq)
        }
      end

      def update
        item = load_item
        if (folder = files_folder(item))
          return redirect_to edit_cp_navigation_path(item.handle), alert: "#{item['title']} is kept in the site's files, so it can't be edited here. Ask a developer to change it."
        end

        result = Nibble::Lifecycle.call(record(item), :save, { "tree" => from_tree_items(params[:tree]) }, actor: Nibble::Current.user)
        return redirect_back_or_to(edit_cp_navigation_path(item.handle), inertia: { errors: { tree: Array(result.errors.values.flatten).first } }) unless result.ok?

        redirect_to edit_cp_navigation_path(item.handle), notice: "Navigation saved."
      end

      private

      # The public site builds this menu from the folders (PageProps#present_navigation), so a row saved here would be
      # read by nothing.
      def files_folder(item)
        collection = Nibble::Files.collections.find { |one| one.handle == item.handle } or return nil
        Nibble::Files.root_for(collection).relative_path_from(Rails.root).to_s
      end

      def render_files_menu(item)
        render inertia: "cp/navigation/Edit", props: {
          menu: menu(item, Nibble.config.default_locale.code),
          tree: [], records: [],
          source: { folder: files_folder(item), links: flatten(Nibble::Files.index.tree(item.handle)) }
        }
      end

      def flatten(links, depth = 0)
        links.flat_map { |link| [ { title: link["title"], url: link["url"], depth: }, *flatten(link["children"], depth + 1) ] }
      end

      def menu(item, locale)
        globals = item["globals"]
        { handle: item.handle, title: item["title"], max_depth: item["max_depth"], locale:,
          headings: item["headings"] == true, assets: item["assets"] == true,
          globals: globals ? Nibble::GlobalLinks.choices.select { |choice| globals == true || Array(globals).include?(choice["handle"]) } : [] }
      end

      def load_item
        item = Nibble.schema.find(:navigation, params[:handle]) or raise ActiveRecord::RecordNotFound
        authorize!("navigation.#{item.handle}.edit")
        item
      end

      def record(item)
        locale = params[:locale].presence || Nibble.config.default_locale.code
        Nibble::Records::NavigationTree.find_or_initialize_by(handle: item.handle, locale:)
      end

      def linkable(item)
        entries = Nibble::Records::Entry.kept.where(collection: Array(item["collections"])).order(:uri)
        terms = Nibble::Records::Term.kept.where(taxonomy: Array(item["taxonomies"])).order(:title)
        entries.map { |entry| summary(entry, "entry", Nibble.schema.collection(entry.collection)) } +
          terms.map { |term| summary(term, "term", Nibble.schema.taxonomy(term.taxonomy)) }
      end

      def summary(record, type, group)
        { id: record.id, type:, title: record.title, path: record.uri, group: group.handle, group_title: group["title"],
          status: record.respond_to?(:status) ? record.status : "published", live: record.live? }
      end

      def to_tree_items(nodes, fields)
        nodes.map do |node|
          kind = Nibble::Records::NavigationTree.kind(node)
          values = node["fields"].to_h
          editing = fields.add_values(values.slice(*fields.handles))
          { id: SecureRandom.uuid, kind:, title: node["title"], link: (tree_link(node) if kind == "link"),
            new_tab: node["new_tab"] == true, hidden: node["hidden"] == true,
            fields: values.except(*fields.handles).merge(editing.pre_process.values), field_meta: editing.meta,
            children: to_tree_items(node["children"].to_a, fields) }
        end
      end

      def tree_link(node)
        case node["type"]
        when "url" then { type: "url", url: node["url"] }
        when "global" then { type: "global", ref: node["ref"] }
        else { type: node["type"], id: node["id"] }
        end
      end

      def from_tree_items(items)
        items = items.respond_to?(:to_unsafe_h) ? items.to_unsafe_h : items
        items = items.values if items.is_a?(Hash)
        Array(items).filter_map do |item|
          item = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item
          next unless item.is_a?(Hash)

          kind = item["kind"].presence || "link"
          node = kind == "link" ? stored_link(item["link"].to_h) : { "kind" => kind }
          node["title"] = item["title"]
          node["new_tab"] = true if ActiveModel::Type::Boolean.new.cast(item["new_tab"])
          node["hidden"] = true if ActiveModel::Type::Boolean.new.cast(item["hidden"])
          node["fields"] = item["fields"].to_hash if item["fields"].is_a?(Hash) && item["fields"].present?
          node.merge("children" => from_tree_items(item["children"]))
        end
      end

      def stored_link(link)
        case link["type"]
        when "url" then { "type" => "url", "url" => link["url"] }
        when "global" then { "type" => "global", "ref" => link["ref"] }
        else { "type" => link["type"], "id" => link["id"].to_i }
        end
      end
    end
  end
end
