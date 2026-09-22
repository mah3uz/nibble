module Nibble
  module Drift
    Issue = Data.define(:source, :message)

    HINT = "add a migration in schema/migrations, or run nibble:check --allow-data-loss".freeze
    DRAFT_COLUMNS = %w[title slug parent_id position published_at unpublish_at template blueprint locale status author_id].freeze

    module_function

    def issues(schema: Nibble.schema, migrations: ContentMigrations.pending)
      covered = Coverage.new(migrations)
      scan = Scan.new(schema)
      snapshot = Records::SchemaSnapshot.latest&.types.to_h
      [
        *scan.orphaned_parents.filter_map { |kind, handle, count| removed_parent(kind, handle, count) unless covered.parent?(kind, handle) },
        *scan.orphaned_blueprints.filter_map { |scope, blueprint, count| removed_blueprint(scope, blueprint, count) unless covered.blueprint?(scope, blueprint) },
        *scan.stranded.filter_map { |(scope, field), count| removed_field(scope, field, count) unless covered.field?(scope, field) },
        *changed_types(scan, snapshot, covered)
      ]
    end

    def record_snapshot!(schema: Nibble.schema)
      types = Scan.new(schema).types
      digest = Digest::SHA256.hexdigest(types.to_json)
      return false if Records::SchemaSnapshot.latest&.digest == digest

      Records::SchemaSnapshot.create!(digest:, types:, created_at: Time.current)
    end

    def removed_parent(kind, handle, count)
      noun = kind == "globals" ? "global set" : kind.singularize
      Issue.new(source: "#{kind}/#{handle}", message: "#{noun} '#{handle}' was removed and #{count} #{'record'.pluralize(count)} still belong to it")
    end

    def removed_blueprint(scope, blueprint, count)
      Issue.new(source: scope, message: "blueprint '#{blueprint}' was removed and #{count} #{'record'.pluralize(count)} still use it; #{HINT}")
    end

    def removed_field(scope, field, count)
      Issue.new(source: scope, message: "#{field} was removed and #{count} #{'record'.pluralize(count)} still hold it; #{HINT}")
    end

    def changed_types(scan, snapshot, covered)
      scan.types.flat_map do |scope, fields|
        fields.filter_map do |field, type|
          before = snapshot.dig(scope, field)
          next if before.nil? || before == type || covered.field?(scope, field)

          count = scan.held.fetch([ scope, field ], 0)
          next if count.zero?

          Issue.new(source: scope, message: "#{field} changed from #{before} to #{type} and #{count} #{'record'.pluralize(count)} hold a value; #{HINT}")
        end
      end
    end

    class Coverage
      def initialize(migrations)
        @operations = migrations.flat_map(&:operations).map { |operation| [ operation.keys.first.to_s, operation.values.first.to_h.stringify_keys ] }
      end

      def field?(scope, field)
        @operations.any? do |name, args|
          next false unless scope == scope_of(args)

          (name == "rename_field" && args["from"] == field) ||
            (name == "move_to_taxonomy" && [ args["field"], args["to"] || args["taxonomy"] ].include?(field))
        end
      end

      def blueprint?(scope, blueprint)
        @operations.any? { |name, args| name == "change_blueprint" && scope == scope_of(args) && args["from"] == blueprint }
      end

      # The operations that exist to empty a collection of its records, so a migration written to answer this
      # very issue is not reported as the reason a site cannot boot.
      def parent?(kind, handle)
        return false unless kind == "collections"

        @operations.any? do |name, args|
          (name == "delete_collection" && args["collection"] == handle) ||
            (name == "rename_collection" && args["from"] == handle)
        end
      end

      private

      def scope_of(args) = args["collection"] ? "collections/#{args['collection']}" : "taxonomies/#{args['taxonomy']}"
    end

    class Scan
      attr_reader :stranded, :held, :orphaned_parents, :orphaned_blueprints

      def initialize(schema)
        @schema = schema
        @stranded = Hash.new(0)
        @held = Hash.new(0)
        @orphaned_parents = []
        @orphaned_blueprints = []
        run
      end

      def types
        @types ||= (scopes("collections") + scopes("taxonomies") + globals).to_h do |scope, blueprints|
          [ scope, blueprints.values.reduce({}) { |merged, fields| fields.merge(merged) } ]
        end
      end

      private

      def run
        { "collections" => [ Records::Entry, :collection ], "taxonomies" => [ Records::Term, :taxonomy ] }.each do |kind, (model, column)|
          known = @schema.all(kind).to_h { |item| [ item.handle, fields_by_blueprint(item) ] }
          count_orphans(kind, model.group(column).count, known)
          scan_rows(kind, model.where(column => known.keys).in_batches, column, known)
        end
        scan_globals
        scan_drafts
      end

      def scan_rows(kind, batches, column, known)
        missing = Hash.new(0)
        batches.each do |batch|
          batch.pluck(column, :blueprint, :data).each do |handle, blueprint, data|
            fields = known.dig(handle, blueprint)
            next missing[[ "#{kind}/#{handle}", blueprint ]] += 1 unless fields

            tally("#{kind}/#{handle}", fields, data)
          end
        end
        missing.each { |(scope, blueprint), count| @orphaned_blueprints << [ scope, blueprint, count ] }
      end

      def scan_globals
        known = @schema.globals.to_h { |item| [ item.handle, item ] }
        count_orphans("globals", Records::GlobalSet.group(:handle).count, known)
        Records::GlobalSet.where(handle: known.keys).find_each do |global|
          tally("globals/#{global.handle}", global.blueprint_fields.all.transform_values(&:type), global.data)
        end
      end

      def scan_drafts
        Records::Draft.includes(:record).find_each do |draft|
          record = draft.record or next
          scope = record.respond_to?(:collection) ? "collections/#{record.collection}" : "taxonomies/#{record.taxonomy}"
          fields = types.dig(scope) or next
          tally(scope, fields, draft.data.to_h.except(*DRAFT_COLUMNS), count_held: false)
        end
      end

      def tally(scope, fields, data, count_held: true)
        data.to_h.each do |key, value|
          next if value.nil?

          if fields.key?(key)
            @held[[ scope, key ]] += 1 if count_held
          else
            @stranded[[ scope, key ]] += 1
          end
        end
      end

      def count_orphans(kind, counts, known)
        counts.each { |handle, count| @orphaned_parents << [ kind, handle, count ] unless known.key?(handle) }
      end

      def scopes(kind) = @schema.all(kind).map { |item| [ "#{kind}/#{item.handle}", fields_by_blueprint(item) ] }

      def globals
        @schema.globals.map do |item|
          record = Records::GlobalSet.new(handle: item.handle, locale: Nibble.config.default_locale.code)
          [ "globals/#{item.handle}", { "default" => record.blueprint_fields.all.transform_values(&:type) } ]
        end
      end

      def fields_by_blueprint(item)
        @schema.blueprints_for(item).to_h { |blueprint| [ blueprint.handle, Blueprint.new(blueprint, schema: @schema).fields.all.transform_values(&:type) ] }
      end
    end
  end
end
