module Nibble
  class Check
    Problem = Data.define(:source, :message, :level) do
      def initialize(source:, message:, level: :error) = super

      def to_s = "#{source}: #{message}"
    end

    RESERVED_ENTRY_HANDLES = %w[
      id uuid collection blueprint locale origin origin_id uri url status parent parent_id position template slug
      published_at unpublish_at created_at updated_at deleted_at lock_version created_by updated_by type
    ].freeze

    attr_reader :problems, :warnings

    def self.run(config: Nibble.config, allow_data_loss: false, static: false) = new(config:, allow_data_loss:, static:).tap(&:run)

    def initialize(config:, allow_data_loss: false, static: false)
      @config = config
      @allow_data_loss = allow_data_loss
      @static = static
      @problems = []
      @warnings = []
    end

    def ok? = problems.empty?

    # Every finding in one list, so a screen can show warnings instead of dropping them.
    def findings = problems + warnings

    def run
      schema = capture("schema") { Schema.load(@config) } or return self

      schema.fieldsets.each { |item| capture(item.path) { check_fields(Fields.new(item["fields"], schema:, source: item.path, key: "fields"), item.path) } }
      (schema.collections + schema.taxonomies).each do |parent|
        schema.blueprints_for(parent).each do |item|
          capture(item.path) do
            blueprint = Blueprint.new(item, schema:)
            check_fields(blueprint.fields, item.path)
            check_reserved(blueprint.fields, item.path) if parent.kind == "collections"
          end
        end
      end
      schema.globals.each do |item|
        inline = Schema::Item.new(kind: "blueprints", handle: item.handle, parent: item.key, path: item.path, layer: item.layer, data: item["blueprint"])
        capture(item.path) { check_fields(Blueprint.new(inline, schema:).fields, item.path) }
      end
      schema.forms.each do |item|
        capture(item.path) do
          form = Forms::Form.new(item:)
          check_fields(form.fields(schema:), item.path)
          Forms.problems(form, schema:).each { |message| problem(item.path, message) }
        end
      end
      # A build has no database and no secrets, so what needs either is checked where the site runs.
      check_database(schema) unless @static
      check_navigation(schema)
      check_icons(schema)
      check_search(schema)
      check_sidecars(schema)
      check_theme(schema)
      check_ejections if @config.equal?(Nibble.config)
      check_environment unless @static
      self
    end

    private

    def capture(source)
      yield
    rescue SchemaError, Error => e
      @problems << Problem.new(source: source.to_s.delete_prefix("#{Rails.root}/"), message: e.message.delete_prefix("#{source.to_s.delete_prefix("#{Rails.root}/")}: "))
      nil
    end

    def check_fields(fields, source)
      fields.each do |field|
        (field.validation_rules + Validation.explode(field.fieldtype.rules)).each do |rule|
          name = rule.to_s.split(":", 2).first
          problem(source, "field '#{field.path}' uses unknown validation rule '#{name}'") unless Validation.known?(name)
        end
        field.fieldtype.nested_fields.each { |nested| check_fields(nested, source) }
      end
    end

    def check_reserved(fields, source)
      (fields.handles & RESERVED_ENTRY_HANDLES).each do |handle|
        problem(source, "field handle '#{handle}' is reserved for the entry itself")
      end
    end

    def check_database(schema)
      return problem("database", "not set up, or has migrations to run: run bin/rails db:prepare") if database_behind?

      check_roles(schema)
      capture("site/schema/migrations") { ContentMigrations.pending } if @config.equal?(Nibble.config)
      check_drift(schema) if @config.equal?(Nibble.config)
    end

    def database_behind? = ActiveRecord::Base.connection_pool.migration_context.needs_migration?

    def check_roles(schema)
      return unless @config.equal?(Nibble.config)

      Role.where(superuser: false).find_each do |role|
        Access::Catalogue.unknown(role.abilities, schema:).each do |ability|
          problem("role '#{role.handle}'", "ability '#{ability}' doesn't match anything in this site's schema")
        end
      end
    rescue ActiveRecord::StatementInvalid
      nil
    end

    def check_drift(schema)
      migrations = begin
        ContentMigrations.pending
      rescue Error
        []
      end
      Drift.issues(schema:, migrations:).each do |issue|
        (@allow_data_loss ? @warnings : @problems) << Problem.new(source: issue.source, message: issue.message, level: @allow_data_loss ? :warning : :error)
      end
    rescue ActiveRecord::StatementInvalid
      nil
    end

    def check_navigation(schema)
      schema.navigations.each do |item|
        Array(item["collections"]).each { |handle| problem(item.path, "collection '#{handle}' doesn't exist") unless schema.collection(handle) }
        Array(item["taxonomies"]).each { |handle| problem(item.path, "taxonomy '#{handle}' doesn't exist") unless schema.taxonomy(handle) }
      end
    end

    def check_icons(schema)
      (schema.collections + schema.taxonomies).each do |item|
        next if item["icon"].nil? || Cp::Navigation.icon?(item["icon"])

        problem(item.path, "icon '#{item['icon']}' isn't one of the Control Plane icons in #{Cp::Navigation::ICONS_PATH}")
      end
    end

    def check_search(schema)
      search = schema.search or return

      if @config.defaults_at_least?(Search::KEYS_ONLY_SINCE) && !search.path.to_s.start_with?(Nibble.core_root.to_s)
        search["indexes"].each do |index, definition|
          %w[collections taxonomies].each do |key|
            next if definition.to_h[key].blank?

            problem(search.path, "index '#{index}' lists #{key}, which are no longer read: give each one `search: #{index}` in its own file")
          end
        end
      end

      Search.indexes(schema:, config: @config).each do |index, definition|
        collections = Array(definition["collections"])
        next if collections.empty?

        collections.each { |handle| problem(search.path, "index '#{index}' uses missing collection '#{handle}'") unless schema.collection(handle) }
        available = collections.filter_map { |handle| schema.collection(handle) }
          .flat_map { |collection| schema.blueprints_for(collection) }
          .flat_map { |item| capture(item.path) { Blueprint.new(item, schema:).fields.handles } || [] }
        (Array(definition["fields"]) - available).each do |handle|
          problem(search.path, "index '#{index}' searches field '#{handle}', which no blueprint of its collections defines")
        end
      end
    end

    def check_theme(schema)
      return unless @config.theme_path

      theme = capture(@config.theme_path.join("theme.yml")) { @config.active_theme } or return
      source = theme.path.join("theme.yml")
      theme.manifest_problems.each { |message| problem(source, message.delete_prefix("theme.yml: ")) }
      Theme::REQUIRED_VIEWS.each { |view| problem(theme.views_path, "required view '#{view}.vue' is missing") unless theme.view?(view) }
      problem(theme.layouts_path, "required layout 'default.vue' is missing") unless theme.layout?("default")
      set_handles(schema).each { |set| problem(theme.views_path, "set '#{set}' has no view sets/#{set}.vue") unless theme.view?("sets/#{set}") }
      schema.collections.select { |item| item["index_route"] }.each do |item|
        view = item["index_template"] || "collections/index"
        problem(item.path, "index_route needs the view #{view}.vue, which #{theme.handle} doesn't have") unless theme.view?(view)
      end
      types = TypeGenerator.output(@config)
      current = capture(types) { TypeGenerator.new(schema, config: @config).generate }
      if current && (!types.file? || types.read != current)
        problem(types, "generated types are out of date: run bin/rails nibble:schema:types")
      end
    end

    def set_handles(schema)
      blueprints = (schema.collections + schema.taxonomies).flat_map { |parent| schema.blueprints_for(parent) }
      fields = blueprints.flat_map { |item| capture(item.path) { Blueprint.new(item, schema:).fields.all.values } || [] }
      nested_sets(fields).uniq.sort
    end

    def nested_sets(fields)
      fields.flat_map do |field|
        fieldtype = field.fieldtype
        own = fieldtype.respond_to?(:sets_config) ? fieldtype.sets_config.keys : []
        own + fieldtype.nested_fields.flat_map { |nested| nested_sets(nested.all.values) }
      end
    end

    def check_sidecars(schema)
      Views.sidecars(config: @config).each do |sidecar|
        sidecar.queries.each do |prop, spec|
          Query::Spec.parse(spec, schema:)
        rescue Query::Invalid => e
          problem(sidecar.path, "query '#{prop}' #{e.message}")
        end
      rescue SchemaError => e
        problem(e.file, e.message)
      end
    end

    def check_environment
      Environment.findings(config: @config).each do |finding|
        problem = Problem.new(source: finding.source, message: finding.message, level: finding.level)
        finding.level == :error ? @problems << problem : @warnings << problem
      end
    end

    def check_ejections
      Eject.stale.each do |ejection|
        @warnings << Problem.new(source: ejection.target, message: "#{ejection.source} has changed since you took this copy on #{ejection.at}", level: :warning)
      end
      Eject.unmanaged.each do |path|
        @warnings << Problem.new(source: path, message: "changed here rather than ejected, so the next upgrade will refuse until it is put back", level: :warning)
      end
    end

    def problem(source, message) = @problems << Problem.new(source: source.to_s.delete_prefix("#{Rails.root}/"), message:)
  end
end
