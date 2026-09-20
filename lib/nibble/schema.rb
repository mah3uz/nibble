module Nibble
  class Schema
    def self.layers(config = Nibble.config)
      layers = [ [ :core, Nibble.core_schema_path ] ]
      layers << [ :theme, config.theme_path.join("schema") ] if config.theme_path
      layers << [ :site, Nibble.site_schema_path ]
    end

    def self.load(config = Nibble.config)
      theme_disabled = config.theme_path&.join("theme.yml")&.file? ? config.active_theme.disable : []
      new(Loader.new(layers: layers(config), disabled: config.disable + theme_disabled).load)
    end

    attr_reader :items

    def initialize(items)
      @items = items
      @by_key = items.index_by(&:key)
    end

    def find(kind, handle) = @by_key["#{kind}/#{handle}"]

    # Blueprints are immutable once built, so each one is built once per loaded schema.
    def built_blueprint(item)
      (@blueprints ||= Concurrent::Map.new).compute_if_absent([ item.key, item.data.object_id ]) { Blueprint.new(item, schema: self) }
    end

    def fetch(kind, handle)
      find(kind, handle) or raise Error, "no #{kind.to_s.singularize} '#{handle}' in the schema"
    end

    def all(kind) = items.select { |item| item.kind == kind.to_s }.sort_by(&:handle)

    def collections = all(:collections)
    def taxonomies = all(:taxonomies)
    def globals = all(:globals)
    def navigations = all(:navigation)
    def forms = all(:forms)
    def apis = all(:apis)
    def fieldsets = all(:fieldsets)
    def search = find(:search, "search")

    def collection(handle) = find(:collections, handle)
    def taxonomy(handle) = find(:taxonomies, handle)
    def fieldset(handle) = find(:fieldsets, handle)

    # Ordered as the parent lists them: the first is the default blueprint.
    def blueprints_for(parent)
      Array(parent["blueprints"]).map { |handle| @by_key.fetch("blueprints/#{parent.key}/#{handle}") }
    end

    def blueprint(parent, handle) = @by_key["blueprints/#{parent.key}/#{handle}"]

    def digest
      @digest ||= Digest::SHA256.hexdigest(items.sort_by(&:key).map { |item| [ item.key, item.layer, item.data ] }.to_json)
    end
  end
end
