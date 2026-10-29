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

      schema.fieldsets.each { |item| capture(item.path) { check_fields(Fields.new(item["fields"], schema:, source: item.path, key: "fields"), item.path, calculations: true) } }
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
        capture(item.path) { check_fields(global_blueprint(item, schema).fields, item.path) }
      end
      schema.forms.each do |item|
        capture(item.path) do
          form = Forms::Form.new(item:)
          check_fields(form.fields(schema:), item.path, calculations: true)
          Forms.problems(form, schema:).each { |message| problem(item.path, message) }
          Forms.locale_problems(form, schema:, locales: @config.locales.map(&:code)).each { |message| problem(item.path, message) }
          Forms.warnings(form).each { |message| @warnings << Problem.new(source: item.path.to_s.delete_prefix("#{Rails.root}/"), message:, level: :warning) }
        end
      end
      schema.tasks.each do |item|
        capture(item.path) { Tasks::Problems.for(Tasks::Task.new(item:), schema:).each { |message| problem(item.path, message) } }
      end
      # A build has no database and no secrets, so what needs either is checked where the site runs.
      check_database(schema) unless @static
      check_outbound
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

    def check_fields(fields, source, calculations: false)
      fields.each do |field|
        rule_names = (field.validation_rules + Validation.explode(field.fieldtype.rules)).map { |rule| rule.to_s.split(":", 2).first }
        rule_names.each do |name|
          problem(source, "field '#{field.path}' uses unknown validation rule '#{name}'") unless Validation.known?(name)
        end
        check_messages(field, rule_names, source)
        check_required_condition(field, fields, source)
        problem(source, "field '#{field.path}' is a note, which only displays text: it can't be required, hidden, encrypted or have a default") if note_with_storage_options?(field)
        problem(source, "field '#{field.path}' is a calculation, which only a form can have") if field.type == Forms::Calculations::TYPE && !calculations
        if field.computed_default? && !Defaults.registered?(name = field.get("default").delete_prefix(Field::COMPUTED_DEFAULT_PREFIX))
          problem(source, "field '#{field.path}' has computed default '#{name}', which isn't registered")
        end
        unless Operations::FieldSchema.known?(field)
          @warnings << Problem.new(source:, level: :warning,
            message: "field '#{field.path}' is a #{field.type}, which apps can't be told how to write: give the fieldtype a json_schema")
        end
        field.fieldtype.nested_fields.each { |nested| check_fields(nested, source, calculations:) }
      end
    end

    def note_with_storage_options?(field)
      field.display_only? && (field.config.key?("default") || field.required_condition || %w[required hidden encrypt].any? { |key| field.get(key) == true } || field.validation_rules.include?("required"))
    end

    def check_messages(field, rule_names, source)
      messages = field.get("messages")
      return unless messages.is_a?(Hash)

      rule_names += [ "required" ] if field.get("required") == true || field.required_condition
      rule_names += [ "step" ] if field.type == "integer" && field.get("step")
      locales = @config.locales.map(&:code)
      messages.each do |rule, message|
        problem(source, "field '#{field.path}' has a message for '#{rule}', which it has no rule for") unless rule_names.include?(rule)
        next unless message.is_a?(Hash)

        (message.keys.map(&:to_s) - locales).each do |code|
          problem(source, "field '#{field.path}' has a '#{rule}' message for locale '#{code}', which the site doesn't have")
        end
      end
    end

    def check_required_condition(field, fields, source)
      condition = field.required_condition or return
      keys = condition.keys.map(&:to_s)
      unless keys.size == 1 && Conditions::KEYS.include?(keys.first)
        return problem(source, "field '#{field.path}' has a required condition that must hold exactly one of #{Conditions::KEYS.join(', ')}")
      end

      rules = condition.values.first
      return if rules.is_a?(String)
      return problem(source, "field '#{field.path}' has a required condition that must map field handles to the values to match") unless rules.is_a?(Hash)

      rules.each_key do |handle|
        name = handle.to_s
        next if name.start_with?("$root.", "root.", "$parent.") || fields.has?(name.split(".").first)

        problem(source, "field '#{field.path}' has a required condition on '#{name}', which isn't a field beside it")
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
      check_captcha(schema)
      check_removed_forms(schema)
      capture("site/schema/migrations") { ContentMigrations.pending } if @config.equal?(Nibble.config)
      check_drift(schema) if @config.equal?(Nibble.config)
      check_uris(schema) if @config.equal?(Nibble.config)
      check_required_toggles(schema) if @config.equal?(Nibble.config)
      check_text_formats(schema) if @config.equal?(Nibble.config)
    end

    def database_behind? = ActiveRecord::Base.connection_pool.migration_context.needs_migration?

    def check_removed_forms(schema)
      Records::FormSubmission.group(:form).count.except(*schema.forms.map(&:handle)).each do |handle, count|
        @warnings << Problem.new(source: "form '#{handle}'", level: :warning,
          message: "has #{count} stored #{'submission'.pluralize(count)} but isn't in the schema; the daily purge deletes them " \
                   "#{Jobs::PurgeSubmissions::REMOVED_FORM_DAYS} days after the form disappears, or after its last retention_days if it had one")
      end
    rescue ActiveRecord::StatementInvalid
      nil
    end

    def check_captcha(schema)
      return if Integrations.captcha

      schema.forms.each do |item|
        next unless Forms::Form.new(item:).captcha?

        @warnings << Problem.new(source: item.path.to_s.delete_prefix("#{Rails.root}/"), level: :warning,
          message: "has captcha: true but Integrations has no CAPTCHA keys, so every submission is refused")
      end
    rescue ActiveRecord::StatementInvalid
      nil
    end

    def check_uris(schema)
      Uris.unsettled(schema:).group_by { |record| record.is_a?(Records::Term) ? [ "taxonomy", record.taxonomy, "term" ] : [ "collection", record.collection, "entry" ] }
        .each do |(kind, handle, noun), records|
          @warnings << Problem.new(source: "#{kind} '#{handle}'", level: :warning,
            message: "has #{records.size} #{noun.pluralize(records.size)} not at the address the route gives; bin/rails nibble:prepare moves them")
        end
    rescue ActiveRecord::StatementInvalid
      nil
    end

    def check_required_toggles(schema)
      each_saved_set(schema) { |source, records, noun, action, blueprint| warn_required_toggles_off(source, records, noun, action, &blueprint) }
    end

    def each_saved_set(schema)
      schema.collections.each do |parent|
        schema.blueprints_for(parent).each do |item|
          yield "collection '#{parent.handle}'", Records::Entry.kept.where(collection: parent.handle, blueprint: item.handle), "entry", "published", -> { Blueprint.new(item, schema:) }
        end
      end
      schema.taxonomies.each do |parent|
        schema.blueprints_for(parent).each do |item|
          yield "taxonomy '#{parent.handle}'", Records::Term.kept.where(taxonomy: parent.handle, blueprint: item.handle), "term", "saved", -> { Blueprint.new(item, schema:) }
        end
      end
      schema.globals.each do |item|
        yield "global '#{item.handle}'", Records::GlobalSet.where(handle: item.handle), "record", "saved", -> { global_blueprint(item, schema) }
      end
    rescue ActiveRecord::StatementInvalid
      nil
    end

    def check_text_formats(schema)
      each_saved_set(schema) { |source, records, noun, _action, blueprint| warn_text_formats(source, records, noun, blueprint) }
    end

    def warn_text_formats(source, records, noun, blueprint)
      checks = blueprint.call.fields.all.values.select { |field| field.type == "text" && %w[email url tel].include?(field.get("input_type")) }.to_h do |field|
        rules = field.validation_rules.select { |rule| rule.to_s.start_with?("regex:") }
        config = { "type" => "text", "input_type" => field.get("input_type") }.merge(rules.any? ? { "validate" => rules } : {})
        [ field.handle, [ field.get("input_type"), Validator.new(Fields.new([ { "handle" => field.handle, "field" => config } ])) ] ]
      end
      return if checks.empty?

      failing = Hash.new { |hash, key| hash[key] = [] }
      records.select(:id, :data).find_each do |record|
        checks.each do |handle, (_, validator)|
          value = record.data.to_h[handle]
          failing[handle] << record.id if value.is_a?(String) && value != "" && !validator.validate(handle => value).valid?
        end
      end
      failing.each do |handle, ids|
        @warnings << Problem.new(source:, level: :warning,
          message: "#{ids.size} #{noun.pluralize(ids.size)} (#{ids.first(5).join(', ')}#{', …' if ids.size > 5}) #{ids.size == 1 ? 'has' : 'have'} a value in the " \
                   "#{checks[handle].first} field '#{handle}' that fails its format check, so #{ids.size == 1 ? 'it' : 'they'} can't be saved until it is corrected")
      end
    rescue SchemaError, Error
      nil
    end

    def warn_required_toggles_off(source, records, noun, action)
      handles = yield.fields.all.values.select { |field| field.type == "toggle" && field.required? }.map(&:handle)
      return if handles.empty?

      off = Hash.new(0)
      records.select(:id, :data).find_each do |record|
        handles.each { |handle| off[handle] += 1 if Fieldtypes::Toggle::OFF.include?(record.data.to_h[handle]) }
      end
      off.each do |handle, count|
        @warnings << Problem.new(source:, level: :warning,
          message: "#{count} #{noun.pluralize(count)} #{count == 1 ? 'has' : 'have'} the required toggle '#{handle}' switched off, so " \
                   "#{count == 1 ? 'it' : 'they'} can't be #{action} until it is switched on or the field is made optional")
      end
    rescue SchemaError, Error
      nil
    end

    def global_blueprint(item, schema)
      Blueprint.new(Schema::Item.new(kind: "blueprints", handle: item.handle, parent: item.key, path: item.path, layer: item.layer, data: item["blueprint"]), schema:)
    end

    def check_outbound
      return unless @config.outbound_allow_private_networks && Environment.deployed?

      problem("outbound.allow_private_networks", "is set in #{Rails.env}, where it is ignored: remove it from config/nibble.yml")
    end

    def check_roles(schema)
      return unless @config.equal?(Nibble.config)

      Nibble::Role.where(superuser: false).find_each do |role|
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
