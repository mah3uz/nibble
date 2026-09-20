module Nibble
  module Packages
    Document = Data.define(:kind, :handle, :locale, :key, :data, :file) do
      def slug = key.split("/").last
      def parent_key = key.count("/") > 1 ? key.split("/")[0..-2].join("/") : nil
      def status = data["status"] || "published"
    end

    Report = Data.define(:errors, :created, :updated, :skipped) do
      def ok? = errors.empty?
    end

    class Reader
      KINDS = %w[collections taxonomies globals navigation].freeze

      attr_reader :errors

      def initialize(root)
        @root = Pathname(root)
        @errors = []
      end

      def documents
        raise Error, "#{@root} isn't a content package directory" unless @root.directory?

        files = Dir.glob("**/*.{yml,yaml,json}", base: @root).sort
        files.filter_map { |relative| document(relative) }
      end

      def redirects = list("redirects")

      def assets = list("assets")

      def list(name)
        file = %W[#{name}.yml #{name}.json].map { |candidate| @root.join(candidate) }.find(&:file?) or return []
        Array(parse(file))
      end

      private

      def document(relative)
        return if relative.start_with?("redirects.", "assets.")

        parts = relative.sub(/\.(ya?ml|json)\z/, "").split("/")
        kind = parts.shift
        return error(relative, "unknown folder '#{kind}' (expected #{KINDS.join(', ')} or redirects.yml)") unless KINDS.include?(kind)

        data = parse(@root.join(relative))
        return error(relative, "must be a map of values") unless data.is_a?(Hash)

        case kind
        when "collections", "taxonomies"
          handle, locale, *slugs = parts
          return error(relative, "expected #{kind}/<handle>/<locale>/<slug>") if slugs.empty?

          Document.new(kind:, handle:, locale:, key: [ handle, *slugs ].join("/"), data:, file: relative)
        else
          handle, locale = parts
          return error(relative, "expected #{kind}/<handle>/<locale>") unless locale && parts.size == 2

          Document.new(kind:, handle:, locale:, key: handle, data:, file: relative)
        end
      end

      def parse(path)
        path.extname == ".json" ? JSON.parse(path.read) : YAML.safe_load_file(path, permitted_classes: [ Date, Time ])
      rescue JSON::ParserError, Psych::SyntaxError => e
        error(path.relative_path_from(@root).to_s, "can't be parsed: #{e.message.lines.first.strip}")
        {}
      end

      def error(file, message)
        @errors << "#{file}: #{message}"
        nil
      end
    end

    class References
      def initialize(documents)
        @package = documents.select { |doc| %w[collections taxonomies].include?(doc.kind) }.index_by { |doc| [ doc.kind == "collections" ? "entry" : "term", doc.locale, doc.key ] }
        @ids = {}
      end

      def known?(type, locale, key) = @package.key?([ type, locale, key ]) || existing(type, locale, key).present?

      def record!(document, record) = @ids[[ record.record_type, document.locale, document.key ]] = record.id

      def id(type, locale, key)
        @ids[[ type, locale, key ]] || existing(type, locale, key)&.id
      end

      def existing(type, locale, key)
        handle, *slugs = key.to_s.split("/")
        return nil if slugs.empty? && type != "asset"

        if type == "asset"
          Records::Asset.kept.find_by(folder: slugs.any? ? [ handle, *slugs[0..-2] ].join("/") : "", filename: slugs.last || handle)
        elsif type == "term"
          Records::Term.kept.find_by(taxonomy: handle, locale:, slug: slugs.join("/"))
        else
          slugs.reduce(nil) do |parent, slug|
            found = Records::Entry.kept.find_by(collection: handle, locale:, slug:, parent_id: parent&.id)
            found or break nil
          end
        end
      end
    end

    class Context
      def initialize(references, locale, strict:)
        @references = references
        @locale = locale
        @strict = strict
      end

      def resolve(type, key)
        return key.to_s if key.to_s.match?(/\A\d+\z/)

        id = @references.id(type.to_s, @locale, key)
        raise Error, "unknown #{type} reference '#{key}'" if id.nil? && @strict

        id&.to_s
      end
    end

    class ValidationResolver
      def initialize(references, locale, type)
        @references = references
        @locale = locale
        @type = type
      end

      def find(ids, scope: {}) = ids.select { |key| @references.known?(@type, @locale, key.to_s) }.map { |key| { "id" => key.to_s } }
      def resolve(key) = @references.known?(@type, @locale, key.to_s) ? { url: nil, title: key } : nil
    end

    class Importer
      MODES = %w[create update].freeze
      COLUMN_KEYS = %w[blueprint status published_at unpublish_at template].freeze
      ASSET_KEYS = %w[title alt caption credit focal_x focal_y focal_zoom tags].freeze

      def initialize(root, mode: "create", dry_run: false, notify: false)
        raise Error, "MODE=#{mode} isn't supported (available: #{MODES.join(', ')})" unless MODES.include?(mode.to_s)

        @reader = Reader.new(root)
        @update = mode.to_s == "update"
        @dry_run = dry_run
        @lifecycle_mode = notify ? :import_notify : :import
      end

      def validate
        @documents = @reader.documents
        @redirects = @reader.redirects
        @references = References.new(@documents)
        @assets = @reader.assets
        errors = @reader.errors + @documents.flat_map { |doc| document_errors(doc) } + redirect_errors + asset_errors
        Report.new(errors:, created: [], updated: [], skipped: [])
      end

      def preview
        report = nil
        ActiveRecord::Base.transaction do
          report = call
          raise ActiveRecord::Rollback
        end
        report
      end

      def call
        report = validate
        return report unless report.ok? && !@dry_run

        created = []
        updated = []
        skipped = []
        ActiveRecord::Base.transaction do
          records = []
          existing = []
          entries_and_terms.each do |doc|
            if (record = @references.existing(record_type(doc), doc.locale, doc.key))
              @references.record!(doc, record)
              existing << [ doc, record ]
            else
              records << [ doc, create(doc) ]
              created << doc.file
            end
          end
          records.each { |doc, record| fill_references(doc, record) }
          records.each { |doc, record| publish(doc, record) if doc.kind == "collections" && doc.status == "published" }
          existing.each { |doc, record| (@update && update(doc, record) ? updated : skipped) << doc.file }
          @documents.select { |doc| doc.kind == "globals" }.each { |doc| tally(save_global(doc), doc.file, created, updated, skipped) }
          @documents.select { |doc| doc.kind == "navigation" }.each { |doc| tally(save_navigation(doc), doc.file, created, updated, skipped) }
          @redirects.each { |row| tally(save_redirect(row), "redirects.yml: #{row['from']}", created, updated, skipped) }
          @assets.each { |row| tally(save_asset(row), "assets.yml: #{row['path']}", created, updated, skipped) }
        end
        Report.new(errors: [], created:, updated:, skipped:)
      end

      private

      def record_type(doc) = doc.kind == "collections" ? "entry" : "term"

      def entries_and_terms
        @documents.select { |doc| %w[collections taxonomies].include?(doc.kind) }.sort_by { |doc| [ doc.kind == "taxonomies" ? 0 : 1, doc.key.count("/") ] }
      end

      def document_errors(doc)
        return [ "#{doc.file}: locale '#{doc.locale}' isn't configured" ] unless Nibble.config.locale(doc.locale)

        case doc.kind
        when "collections" then entry_errors(doc)
        when "taxonomies" then term_errors(doc)
        when "globals" then global_errors(doc)
        when "navigation" then navigation_errors(doc)
        end
      end

      def entry_errors(doc)
        collection = Nibble.schema.collection(doc.handle) or return [ "#{doc.file}: no collection '#{doc.handle}'" ]
        record = Records::Entry.new(collection: doc.handle, locale: doc.locale, blueprint: doc.data["blueprint"] || Array(collection["blueprints"]).first)
        return [ "#{doc.file}: '#{record.blueprint}' isn't a blueprint of #{doc.handle}" ] unless record.blueprint_item

        errors = []
        errors << "#{doc.file}: status must be published or draft" unless %w[published draft].include?(doc.status)
        errors << "#{doc.file}: slug '#{doc.slug}' isn't a valid slug" unless doc.slug.match?(Records::Entry::SLUG)
        errors << "#{doc.file}: parent '#{doc.parent_key}' isn't in the package or the site" if doc.parent_key && !@references.known?("entry", doc.locale, doc.parent_key)
        errors << "#{doc.file}: published_at is required to publish a dated entry" if doc.status == "published" && record.dated? && doc.data["published_at"].blank?
        errors + field_errors(doc, record, full: doc.status == "published")
      end

      def term_errors(doc)
        taxonomy = Nibble.schema.taxonomy(doc.handle) or return [ "#{doc.file}: no taxonomy '#{doc.handle}'" ]
        record = Records::Term.new(taxonomy: doc.handle, locale: doc.locale, blueprint: doc.data["blueprint"] || Array(taxonomy["blueprints"]).first)
        return [ "#{doc.file}: '#{record.blueprint}' isn't a blueprint of #{doc.handle}" ] unless record.blueprint_item

        field_errors(doc, record, full: true)
      end

      def global_errors(doc)
        record = Records::GlobalSet.new(handle: doc.handle, locale: doc.locale)
        return [ "#{doc.file}: no global set '#{doc.handle}'" ] unless record.item

        field_errors(doc, record, full: true)
      end

      def navigation_errors(doc)
        item = Nibble.schema.find(:navigation, doc.handle) or return [ "#{doc.file}: no navigation '#{doc.handle}'" ]

        links(doc.data["tree"].to_a).filter_map do |node|
          type = (node.keys & %w[entry term]).first
          if type
            "#{doc.file}: link to unknown #{type} '#{node[type]}'" unless @references.known?(type, doc.locale, node[type].to_s)
          elsif node["url"].blank? || node["title"].blank?
            "#{doc.file}: a link needs an entry, a term, or a url and a title"
          end
        end.tap { |errors| errors << "#{doc.file}: navigation #{item.handle} has no tree" if doc.data["tree"].blank? }
      end

      def field_errors(doc, record, full:)
        values = doc.data.except(*COLUMN_KEYS)
        unknown = values.keys - record.blueprint_fields.handles - %w[slug]
        overrides = %w[entry term asset].to_h { |type| [ type, ValidationResolver.new(@references, doc.locale, type) ] }
        errors = Resolvers.with_overrides(overrides) { RecordValues.new(record).validate(values.except("slug"), full:) }
        unknown.map { |key| "#{doc.file}: '#{key}' isn't a field of #{record.blueprint_definition.handle}" } +
          errors.flat_map { |path, messages| messages.map { |message| "#{doc.file}: #{path}: #{message}" } }
      end

      def redirect_errors
        @redirects.each_with_index.filter_map do |row, index|
          next if row.is_a?(Hash) && Records::Redirect.exists?(from: row["from"])

          record = Records::Redirect.new(from: row["from"], to: row["to"], status: row["status"] || 301, source: "import")
          "redirects.yml: #{index}: #{record.errors.full_messages.to_sentence}" unless row.is_a?(Hash) && record.valid?
        end
      end

      def create(doc)
        model = doc.kind == "collections" ? Records::Entry.new(collection: doc.handle) : Records::Term.new(taxonomy: doc.handle)
        model.locale = doc.locale
        item = doc.kind == "collections" ? model.collection_item : model.taxonomy_item
        model.blueprint = doc.data["blueprint"] || Array(item["blueprints"]).first
        attrs = plain_values(doc, model).merge("slug" => doc.slug)
        if doc.kind == "collections"
          attrs.merge!(doc.data.slice("published_at", "unpublish_at", "template"))
          attrs["parent_id"] = @references.id("entry", doc.locale, doc.parent_key) if doc.parent_key
        end
        record = succeed!(doc, Lifecycle.call(model, :create, attrs, mode: @lifecycle_mode))
        @references.record!(doc, record)
        record
      end

      def fill_references(doc, record)
        context = Context.new(@references, doc.locale, strict: true)
        references = record.blueprint_fields.all.select { |handle, _| doc.data.key?(handle) && referencing?(record, handle) }
        return if references.empty?

        attrs = references.to_h { |handle, field| [ handle, field.fieldtype.import(doc.data[handle], context) ] }
        succeed!(doc, Lifecycle.call(record.reload, :save, attrs, mode: @lifecycle_mode))
      end

      def publish(doc, record) = succeed!(doc, Lifecycle.call(record.reload, :publish, {}, mode: @lifecycle_mode))

      def update(doc, record)
        context = Context.new(@references, doc.locale, strict: true)
        fields = record.blueprint_fields.all.select { |handle, _| doc.data.key?(handle) }
        attrs = fields.to_h { |handle, field| [ handle, field.fieldtype.import(doc.data[handle], context) ] }
        columns = doc.kind == "collections" ? doc.data.slice("published_at", "unpublish_at", "template") : {}
        return false if unchanged?(record, attrs, columns) && !(doc.kind == "collections" && doc.status == "published" && !record.live?)

        succeed!(doc, Lifecycle.call(record, :save, attrs.merge(columns), mode: @lifecycle_mode))
        publish(doc, record) if doc.kind == "collections" && doc.status == "published"
        true
      end

      def unchanged?(record, attrs, columns)
        stored = record.blueprint_fields.add_values(record.values).values
        incoming = record.blueprint_fields.add_values(record.values.merge(attrs)).process.values
        fields_same = attrs.keys.all? { |handle| normalize(incoming[handle]) == normalize(stored[handle]) }
        fields_same && columns.all? { |key, value| same_column?(record.public_send(key), value) }
      end

      def normalize(value) = JSON.parse(value.to_json)

      def same_column?(current, value)
        return current.to_s == value.to_s unless current.is_a?(Time) || current.is_a?(ActiveSupport::TimeWithZone)

        current == Time.zone.parse(value.to_s)
      end

      def tally(outcome, label, created, updated, skipped)
        { created:, updated:, skipped: }[outcome]&.push(label)
      end

      def save_global(doc)
        record = Records::GlobalSet.find_or_initialize_by(handle: doc.handle, locale: doc.locale)
        outcome = record.persisted? ? :updated : :created
        return :skipped if record.persisted? && !@update

        context = Context.new(@references, doc.locale, strict: true)
        attrs = record.blueprint_fields.all.select { |handle, _| doc.data.key?(handle) }.to_h { |handle, field| [ handle, field.fieldtype.import(doc.data[handle], context) ] }
        return :skipped if record.persisted? && unchanged?(record, attrs, {})

        succeed!(doc, Lifecycle.call(record, :save, attrs, mode: @lifecycle_mode))
        outcome
      end

      def save_navigation(doc)
        record = Records::NavigationTree.find_or_initialize_by(handle: doc.handle, locale: doc.locale)
        outcome = record.persisted? ? :updated : :created
        return :skipped if record.persisted? && !@update

        incoming = tree(doc.data["tree"].to_a, doc.locale)
        return :skipped if record.persisted? && normalize(incoming) == normalize(record.tree.to_a)

        succeed!(doc, Lifecycle.call(record, :save, { "tree" => incoming }, mode: @lifecycle_mode))
        outcome
      end

      def save_redirect(row)
        record = Records::Redirect.find_by(from: row["from"])
        return :skipped if record && (!@update || (record.to == row["to"] && record.status == (row["status"] || 301)))
        return record.update!(to: row["to"], status: row["status"] || 301) && :updated if record

        Records::Redirect.create!(from: row["from"], to: row["to"], status: row["status"] || 301, source: "import")
        :created
      end

      # Binaries travel separately, so a row only ever describes an asset that is already here.
      def save_asset(row)
        asset = @references.existing("asset", nil, row["path"]) or return :skipped
        return :skipped unless @update

        changes = row.slice(*ASSET_KEYS)
        return :skipped if changes.all? { |key, value| asset.public_send(key) == value }

        succeed!(Document.new(kind: "assets", handle: "assets", locale: nil, key: row["path"], data: row, file: "assets.yml"),
          Lifecycle.call(asset, :save, changes, mode: @lifecycle_mode))
        :updated
      end

      def asset_errors
        @assets.each_with_index.filter_map do |row, index|
          "assets.yml: #{index}: needs a path" unless row.is_a?(Hash) && row["path"].present?
        end
      end

      def plain_values(doc, record)
        doc.data.except(*COLUMN_KEYS, "slug").reject { |handle, _| referencing?(record, handle) }
      end

      def referencing?(record, handle)
        field = record.blueprint_fields.get(handle) or return false
        fieldtype = field.fieldtype
        fieldtype.class.relationship || fieldtype.is_a?(Fieldtypes::Link) || fieldtype.is_a?(Fieldtypes::RichText) ||
          field.fieldtype.nested_fields.any?
      end

      def tree(nodes, locale)
        nodes.map do |node|
          type = (node.keys & %w[entry term]).first
          link = type ? { "type" => type, "id" => @references.id(type, locale, node[type].to_s) } : { "type" => "url", "url" => node["url"] }
          link["title"] = node["title"] if node["title"]
          link.merge("children" => tree(node["children"].to_a, locale))
        end
      end

      def links(nodes) = nodes.flat_map { |node| [ node, *links(node["children"].to_a) ] }

      def succeed!(doc, result)
        return result.record if result.ok?

        raise Error, "#{doc.file}: #{result.errors.map { |key, messages| "#{key}: #{Array(messages).join(', ')}" }.join('; ')}"
      end
    end
  end
end
