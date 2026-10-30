module Nibble
  class Presenter
    MAX_DEPTH = 2

    def self.present(records, fields: nil, include: [], context: Query::Context.public) = new(context:).present(records, fields:, include:)

    def self.url(uri) = uri && "#{Nibble.config.url.to_s.chomp('/')}#{uri}"

    API_HIDES_FIELDS_SINCE = "0.15.0".freeze

    # api: true is the Content API, which leaves out fields marked api: false; a page still receives them.
    def initialize(context:, api: false)
      @context = context
      @api = api
      @preload = Preload.new(context:)
    end

    def present(records, fields: nil, include: [], depth: 1)
      records = Array(records)
      @preload.load(records)
      Resolvers.with_overrides(@preload.resolvers) do
        records.map { |record| present_one(record, fields:, include:, depth:, seen: Set[key(record)]) }
      end
    end

    def preload(records) = @preload.load(records)

    def present_global(global)
      Dependencies.add("global:#{global.handle}")
      @preload.load([ global ])
      Resolvers.with_overrides(@preload.resolvers) do
        values = global.blueprint_fields.add_values(global.values).augment.values
        { "handle" => global.handle, "locale" => global.locale }.merge(values.except(*hidden(global.blueprint_fields)))
      end
    end

    def present_navigation(tree)
      Dependencies.add("navigation:#{tree.handle}")
      return [] unless tree.item

      @preload.load([ tree ])
      menu = tree.menu
      @preload.load(tree.links.filter_map { |node| @preload.record("entry", node["id"]) if node["type"] == "entry" }) if menu.entry_fields.any?
      nodes(tree.tree.to_a, menu)
    end

    private

    def present_one(record, fields:, include:, depth:, seen:)
      Dependencies.add("#{record.record_type}:#{record.id}")
      data = base(record)
      data["parent"] = parent(record) if fields&.include?("parent")
      return data if fields && (fields - data.keys).empty?

      field_set = record.blueprint_fields
      field_set = field_set.only(fields) if fields
      data_values = record.has_attribute?(:data) ? record.values : { "title" => record.title }
      augmented = field_set.add_values(data_values).augment.values
      include.each do |handle|
        next unless augmented.key?(handle) && depth < MAX_DEPTH

        augmented[handle] = expand(record, handle, depth:, seen:)
      end
      data.merge(augmented.except(*data.keys, *hidden(field_set)))
    end

    def hidden(fields)
      display_only = fields.all.values.select(&:display_only?).map(&:handle)
      return display_only unless @api && Nibble.config.defaults_at_least?(API_HIDES_FIELDS_SINCE)

      display_only + fields.all.values.reject(&:api?).map(&:handle)
    end

    def expand(record, handle, depth:, seen:)
      field = record.blueprint_fields.get(handle)
      targets = field.fieldtype.relations(record.values[handle]).filter_map do |type, id|
        target = @preload.record(type, id) or next
        next if seen.include?(key(target))

        present_one(target, fields: nil, include: [], depth: depth + 1, seen: seen | [ key(target) ])
      end
      field.fieldtype.single? ? targets.first : targets
    end

    def base(record)
      {
        "id" => record.id, "uuid" => record.uuid, "type" => record.record_type,
        (record.respond_to?(:collection) ? "collection" : "taxonomy") => record.respond_to?(:collection) ? record.collection : record.taxonomy,
        "blueprint" => record.blueprint, "locale" => record.locale, "title" => record.title, "slug" => record.slug,
        "uri" => record.uri, "url" => self.class.url(record.uri),
        "status" => record.respond_to?(:status) ? record.status : nil,
        "published_at" => record.respond_to?(:published_at) ? record.published_at&.utc&.iso8601 : nil,
        "updated_at" => record.updated_at&.utc&.iso8601,
        "author" => author(record)
      }
    end

    def parent(record)
      parent = record.respond_to?(:parent) && record.parent or return nil

      Dependencies.add("#{parent.record_type}:#{parent.id}")
      { "title" => parent.title, "uri" => parent.uri }
    end

    def author(record)
      user = @preload.author(record.try(:author_id)) or return nil
      { "id" => user.id, "name" => user.name }
    end

    # An item whose kind, query or dates the menu no longer allows is left out rather than shown in a shape the theme doesn't expect.
    def nodes(list, menu)
      list.filter_map do |node|
        next if node["hidden"] == true || !Records::NavigationTree.shown?(node, @context.now)

        kind = Records::NavigationTree.kind(node)
        custom = menu.kind(kind)
        link = case kind
        when "link" then link(node)
        when "heading" then unlinked(node) if menu.headings?
        when "query" then unlinked(node) if menu.queries.include?(MenuQuery.new(node["query"]).collection)
        else (custom.link != "none" && Records::NavigationTree.linked?(node) ? link(node) : unlinked(node)) if custom
        end
        next unless link

        children = if kind == "query" then query_links(node["query"], menu) or next
        elsif custom && !custom.children then []
        else nodes(node["children"].to_a, menu)
        end
        item(link, kind, node, menu, children)
      end
    end

    def item(link, kind, node, menu, children)
      target = link.delete("target")
      link.merge(
        "kind" => kind, "new_tab" => node["new_tab"] == true,
        "fields" => augmented(menu.fields_for(kind), node["fields"]),
        "entry" => (augmented(target.blueprint_fields.only(menu.entry_fields), target.values) if target.is_a?(Records::Entry) && menu.entry_fields.any?),
        "children" => children
      )
    end

    def unlinked(node) = { "type" => nil, "title" => node["title"], "url" => nil }

    def query_links(query, menu)
      records = MenuQuery.new(query).records(@context)
      @preload.load(records) if menu.entry_fields.any?
      records.map { |record| item(record_link("entry", record, nil), "link", {}, menu, []) }
    rescue Query::Invalid
      nil
    end

    def link(node)
      case node["type"]
      when "url" then { "type" => "url", "title" => node["title"], "url" => node["url"] }
      when "global"
        url = GlobalLinks.address(node["ref"]).presence or return nil
        { "type" => "global", "title" => node["title"], "url" => url }
      when *Records::NavigationTree::RECORD_LINKS
        target = @preload.record(node["type"], node["id"]) or return nil
        record_link(node["type"], target, node["title"])
      end
    end

    def record_link(type, target, title)
      Dependencies.add("#{target.record_type}:#{target.id}")
      name, url = target.is_a?(Records::Asset) ? [ target.display_title, target.url ] : [ target.title, target.uri ]
      { "type" => type, "id" => target.id, "title" => title.presence || name, "url" => url, "target" => target }
    end

    def augmented(fields, values)
      return {} if fields.empty?

      Resolvers.with_overrides(@preload.resolvers) { fields.add_values(values.to_h.stringify_keys).augment.values.except(*hidden(fields)) }
    end

    def key(record) = "#{record.record_type}:#{record.id}"
  end
end
