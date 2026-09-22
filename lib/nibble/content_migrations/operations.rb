module Nibble
  module ContentMigrations
    module Operations
      NAMES = %w[rename_field change_blueprint set_default move_to_taxonomy delete_collection rename_collection].freeze
      REMOVED = %w[delete_collection rename_collection].freeze
      COLUMNS = %w[title slug].freeze

      module_function

      def apply(operation)
        name, args = operation.first
        public_send(name, args.stringify_keys)
      end

      def validate!(operation, where)
        unless operation.is_a?(Hash) && operation.size == 1 && NAMES.include?(operation.keys.first.to_s)
          raise Error, "#{where}: must be one of #{NAMES.join(', ')}"
        end

        name, args = operation.first
        args = args.to_h.stringify_keys
        item = target_item(args)
        raise Error, "#{where}: needs a collection or taxonomy that exists" if item.nil? && REMOVED.exclude?(name.to_s)

        problem = public_send("#{name}_problem", args, item)
        raise Error, "#{where}: #{problem}" if problem
      end

      def rename_field(args)
        from, to = args.values_at("from", "to")
        change_data(args, "rename #{label(args)}.#{from} to #{to}") do |data|
          next unless data.key?(from)

          value = data.delete(from)
          data[to] = value if data[to].nil?
          data
        end
      end

      def set_default(args)
        field, value = args.values_at("field", "value")
        change_data(args, "default #{label(args)}.#{field}") do |data|
          data.merge(field => value) if data[field].nil?
        end
      end

      def change_blueprint(args)
        from, to = args.values_at("from", "to")
        count = scope(args).where(blueprint: from).find_each.count do |record|
          record.update_columns(blueprint: to, updated_at: Time.current)
          record.draft&.update_columns(data: record.draft.data.merge("blueprint" => to)) if record.draft&.data&.key?("blueprint")
          saved(record, "blueprint #{from} to #{to}")
        end
        [ "blueprint #{label(args)} #{from} to #{to}", count ]
      end

      def move_to_taxonomy(args)
        field, taxonomy = args.values_at("field", "taxonomy")
        to = args["to"] || taxonomy
        change_data(args, "move #{label(args)}.#{field} to #{taxonomy}") do |data, record|
          names = Array(data[field]).map { |name| name.to_s.strip }.compact_blank
          next if names.empty?

          ids = names.map { |name| term(taxonomy, record.locale, name).id.to_s }
          single = record.blueprint_fields.get(to)&.fieldtype&.single?
          data[to] = single ? ids.first : (Array(data[to]) + ids).uniq
          data.except(field)
        end
      end

      # Removed outright rather than trashed: there is no schema left to restore them under.
      def delete_collection(args)
        handle = args["collection"]
        entries = Records::Entry.where(collection: handle)
        count = entries.count
        # Not through Events: the subscribers build the record's blueprint, and that is exactly what has gone.
        entries.find_each do |entry|
          Search.remove(entry)
          Records::Draft.where(record_type: Records::Entry.name, record_id: entry.id).delete_all
          Records::Revision.where(record_type: Records::Entry.name, record_id: entry.id).delete_all
          Records::Relation.where(source_type: Records::Entry.name, source_id: entry.id).delete_all
          Records::Relation.where(target_type: Records::Entry.name, target_id: entry.id).delete_all
        end
        PageCache.purge("collection:#{handle}")
        Records::Entry.where(collection: handle).update_all(parent_id: nil)
        entries.delete_all
        [ "delete #{handle}", count ]
      end

      # A handle is stored on every record, so renaming one in the schema strands them all. Addresses come from
      # the route and are left alone: a rename is not a move.
      def rename_collection(args)
        from, to = args.values_at("from", "to")
        entries = Records::Entry.where(collection: from)
        count = entries.count
        entries.update_all(collection: to)
        # The index files a record under its collection, so every one of them is now under the wrong scope.
        Records::Entry.where(collection: to).find_each { |entry| Search.index_record(entry) }
        PageCache.purge("collection:#{from}")
        [ "rename #{from} to #{to}", count ]
      end

      def rename_collection_problem(args, _item)
        from, to = args.values_at("from", "to")
        return "needs from and to" if from.blank? || to.blank?
        return "from and to are the same collection" if from == to
        return "collection '#{from}' is still in the schema" if Nibble.schema.collection(from)

        "collection '#{to}' isn't in the schema" unless Nibble.schema.collection(to)
      end

      def delete_collection_problem(args, _item)
        return "only deletes a collection" if args["collection"].blank?

        "collection '#{args['collection']}' is still in the schema" if Nibble.schema.collection(args["collection"])
      end

      def rename_field_problem(args, _item)
        return "needs from and to" if args["from"].blank? || args["to"].blank?
        return "from and to are the same field" if args["from"] == args["to"]

        "#{(COLUMNS & [ args['from'], args['to'] ]).first} isn't a field that can be renamed" if COLUMNS.intersect?([ args["from"], args["to"] ])
      end

      def set_default_problem(args, _item)
        return "needs a field" if args["field"].blank?

        "needs a value" unless args.key?("value")
      end

      def change_blueprint_problem(args, item)
        return "needs from and to" if args["from"].blank? || args["to"].blank?

        "'#{args['to']}' isn't a blueprint of #{item.handle}" unless Array(item["blueprints"]).include?(args["to"])
      end

      def move_to_taxonomy_problem(args, _item)
        return "only moves entries of a collection" if args["collection"].blank?
        return "needs a field and a taxonomy" if args["field"].blank? || args["taxonomy"].blank?

        "no taxonomy '#{args['taxonomy']}'" unless Nibble.schema.taxonomy(args["taxonomy"])
      end

      def change_data(args, message)
        count = scope(args).find_each.count do |record|
          data = yield(record.data.to_h.deep_dup, record)
          draft_data = record.draft && yield(record.draft.data.to_h.deep_dup, record)
          changed = data && data != record.data
          draft_changed = draft_data && draft_data != record.draft.data
          record.update_columns(data:, updated_at: Time.current) if changed
          record.draft.update_columns(data: draft_data) if draft_changed
          (changed || draft_changed) && saved(record, message)
        end
        [ message, count ]
      end

      def saved(record, message)
        Revisions.write(record.reload, :import, snapshot: record.snapshot, actor: nil, message:)
        Events.publish("record.saved", record.event_payload.merge("mode" => "import", "changes" => {}))
        true
      end

      def term(taxonomy, locale, title)
        slug = title.parameterize
        Records::Term.find_by(taxonomy:, locale:, slug:) ||
          Lifecycle.call(Records::Term.new(taxonomy:, locale:), :create, { "title" => title, "slug" => slug }, mode: :import).then do |result|
            result.ok? ? result.record : raise(Error, "couldn't create #{taxonomy} term '#{title}': #{result.errors}")
          end
      end

      def scope(args)
        args["collection"] ? Records::Entry.where(collection: args["collection"]) : Records::Term.where(taxonomy: args["taxonomy"])
      end

      def target_item(args)
        args["collection"] ? Nibble.schema.collection(args["collection"]) : Nibble.schema.taxonomy(args["taxonomy"].to_s)
      end

      def label(args) = args["collection"] || args["taxonomy"]
    end
  end
end
