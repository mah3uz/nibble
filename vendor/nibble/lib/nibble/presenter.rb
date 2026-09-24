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
      @preload.load([ tree ])
      nodes(tree.tree.to_a)
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
      return [] unless @api && Nibble.config.defaults_at_least?(API_HIDES_FIELDS_SINCE)

      fields.all.values.reject(&:api?).map(&:handle)
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

    def nodes(list)
      list.filter_map do |node|
        children = nodes(node["children"].to_a)
        if node["type"] == "url"
          { "type" => "url", "title" => node["title"], "url" => node["url"], "children" => children }
        else
          target = @preload.record(node["type"], node["id"]) or next
          Dependencies.add("#{target.record_type}:#{target.id}")
          { "type" => node["type"], "id" => target.id, "title" => node["title"].presence || target.title, "url" => target.uri, "children" => children }
        end
      end
    end

    def key(record) = "#{record.record_type}:#{record.id}"
  end
end
