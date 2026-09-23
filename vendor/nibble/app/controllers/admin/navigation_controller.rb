module Admin
  class NavigationController < BaseController
    def index
      menus = Nibble.schema.navigations.select { |item| Nibble::Access.can?(Current.user, "navigation.#{item.handle}.edit") }
      raise NotAuthorized if menus.empty?

      render inertia: "admin/navigation/Index", props: {
        menus: menus.map { |item| { handle: item.handle, title: item["title"], url: "/admin/navigation/#{item.handle}/edit" } }
      }
    end

    def edit
      item = load_item
      return render_files_menu(item) if (folder = files_folder(item))

      tree = record(item)
      render inertia: "admin/navigation/Edit", props: {
        menu: { handle: item.handle, title: item["title"], max_depth: item["max_depth"] || 3, locale: tree.locale },
        tree: to_tree_items(tree.tree.to_a),
        records: linkable(item)
      }
    end

    def update
      item = load_item
      if (folder = files_folder(item))
        return redirect_to edit_admin_navigation_path(item.handle), alert: "#{item['title']} is built from #{folder}. Change the files and deploy."
      end

      result = Nibble::Lifecycle.call(record(item), :save, { "tree" => from_tree_items(params[:tree]) }, actor: Current.user)
      return redirect_back_or_to(edit_admin_navigation_path(item.handle), inertia: { errors: { tree: Array(result.errors.values.flatten).first } }) unless result.ok?

      redirect_to edit_admin_navigation_path(item.handle), notice: "Navigation saved."
    end

    private

    # The public site builds this menu from the folders (PageProps#present_navigation), so a row saved here would be
    # read by nothing.
    def files_folder(item)
      collection = Nibble::Files.collections.find { |one| one.handle == item.handle } or return nil
      Nibble::Files.root_for(collection).relative_path_from(Rails.root).to_s
    end

    def render_files_menu(item)
      render inertia: "admin/navigation/Edit", props: {
        menu: { handle: item.handle, title: item["title"], max_depth: item["max_depth"] || 3, locale: Nibble.config.default_locale.code },
        tree: [], records: [],
        source: { folder: files_folder(item), links: flatten(Nibble::Files.index.tree(item.handle)) }
      }
    end

    def flatten(links, depth = 0)
      links.flat_map { |link| [ { title: link["title"], url: link["url"], depth: }, *flatten(link["children"], depth + 1) ] }
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

    def to_tree_items(nodes)
      nodes.map do |node|
        link = node["type"] == "url" ? { type: "url", url: node["url"] } : { type: node["type"], id: node["id"] }
        { id: SecureRandom.uuid, title: node["title"], link:, children: to_tree_items(node["children"].to_a) }
      end
    end

    def from_tree_items(items)
      items = items.respond_to?(:to_unsafe_h) ? items.to_unsafe_h : items
      items = items.values if items.is_a?(Hash)
      Array(items).filter_map do |item|
        item = item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item
        next unless item.is_a?(Hash)

        link = item["link"].to_h
        node = link["type"] == "url" ? { "type" => "url", "url" => link["url"] } : { "type" => link["type"], "id" => link["id"].to_i }
        node.merge("title" => item["title"], "children" => from_tree_items(item["children"]))
      end
    end
  end
end
