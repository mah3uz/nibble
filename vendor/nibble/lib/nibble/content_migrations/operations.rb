module Nibble
  module ContentMigrations
    module Operations
      NAMES = %w[rename_field change_blueprint set_default move_to_taxonomy delete_collection rename_collection move_field remove_field
                 rename_navigation delete_navigation rename_global delete_global].freeze
      REMOVED = %w[delete_collection rename_collection rename_navigation delete_navigation rename_global delete_global].freeze
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
        item = target_item(name.to_s == "move_field" ? ends(args).first : args)
        raise Error, "#{where}: needs a collection, taxonomy or global that exists" if item.nil? && REMOVED.exclude?(name.to_s)

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

      def move_field(args)
        from, to = ends(args)
        message = "move #{label(from)}.#{from['field']} to #{label(to)}.#{to['field']}"
        left = []
        count = if Drift.scope_of(from) == Drift.scope_of(to)
          change_data(from, message) do |data, record|
            case shift(data, data, from["field"], to["field"], args["overwrite"])
            when :moved then data
            when :left then left << record and nil
            end
          end.last
        else
          move_between_globals(from, to, args["overwrite"], message, left)
        end
        left = left.uniq.map { |record| "#{record.record_type} #{record.id} (#{record.locale})" }
        [ left.empty? ? message : "#{message}, leaving #{left.join(', ')} where #{to['field']} already holds a value", count ]
      end

      def remove_field(args)
        field = args["field"]
        change_data(args, "remove #{label(args)}.#{field}") { |data| data.except(field) if data.key?(field) }
      end

      # Removed outright rather than trashed: there is no schema left to restore them under.
      def delete_collection(args)
        handle = args["collection"]
        entries = Records::Entry.where(collection: handle)
        count = entries.count
        # Not through Events: the subscribers build the record's blueprint, and that is exactly what has gone.
        entries.find_each do |entry|
          Search.remove(entry)
          Records::Draft.where(record_type: entry.record_type, record_id: entry.id).delete_all
          Records::Revision.where(record_type: entry.record_type, record_id: entry.id).delete_all
          Records::Relation.where(source_type: entry.record_type, source_id: entry.id).delete_all
          Records::Relation.where(target_type: entry.record_type, target_id: entry.id).delete_all
        end
        PageCache.purge("collection:#{handle}")
        Records::Entry.where(collection: handle).update_all(parent_id: nil)
        entries.delete_all
        Abilities.carry!("entry", handle, nil)
        [ "delete #{handle}", count ]
      end

      # A handle is stored on every record, so renaming one in the schema strands them all. Addresses come from
      # the route and are left alone: a rename is not a move.
      def rename_collection(args)
        from, to = args.values_at("from", "to")
        entries = Records::Entry.where(collection: from)
        count = entries.count
        merged = Records::Entry.where(collection: to).exists?
        entries.update_all(collection: to)
        # The index files a record under its collection, so every one of them is now under the wrong scope.
        Records::Entry.where(collection: to).find_each { |entry| Search.index_record(entry) }
        PageCache.purge("collection:#{from}")
        [ "rename #{from} to #{to}#{carry_permissions(Records::Entry, from, to, merged)}", count ]
      end

      def rename_navigation(args) = rename_set(Records::NavigationTree, args)
      def rename_global(args) = rename_set(Records::GlobalSet, args)
      def delete_navigation(args) = delete_set(Records::NavigationTree, args["navigation"])
      def delete_global(args) = delete_set(Records::GlobalSet, args["global"])

      # Ids are kept, so revisions, drafts and relations follow. A locale the new handle already has is left as it
      # is rather than overwritten.
      def rename_set(model, args)
        from, to = args.values_at("from", "to")
        type = model.record_type
        taken = model.where(handle: to).pluck(:locale)
        count = model.where(handle: from).where.not(locale: taken).update_all(handle: to, updated_at: Time.current)
        left = model.where(handle: from).order(:locale).pluck(:locale)
        PageCache.purge("#{type}:#{from}", "#{type}:#{to}")
        message = "rename #{type} #{from} to #{to}#{carry_permissions(model, from, to, taken.any?)}"
        [ left.empty? ? message : "#{message}, leaving #{left.join(', ')} where #{to} already has one", count ]
      end

      def delete_set(model, handle)
        type = model.record_type
        records = model.where(handle:)
        ids = records.ids
        Records::Draft.where(record_type: type, record_id: ids).delete_all
        Records::Revision.where(record_type: type, record_id: ids).delete_all
        Records::Relation.where(source_type: type, source_id: ids).delete_all
        Records::Relation.where(target_type: type, target_id: ids).delete_all
        records.update_all(origin_id: nil) if model.column_names.include?("origin_id")
        records.delete_all
        Abilities.carry!(type, handle, nil)
        PageCache.purge("#{type}:#{handle}")
        [ "delete #{type} #{handle}", ids.size ]
      end

      # Carried into a handle that already holds records, the old permissions would reach those records too.
      def carry_permissions(model, from, to, merged)
        dropped = Abilities.carry!(model.record_type, from, merged ? nil : to)
        holders = dropped == 1 ? "role or app" : "roles and apps"
        ", dropping #{from}'s permissions from #{dropped} #{holders} as #{to} already had records" if merged && dropped.positive?
      end

      def rename_navigation_problem(args, _item) = rename_problem(:navigation, "navigation", args)
      def rename_global_problem(args, _item) = rename_problem(:globals, "global set", args)
      def delete_navigation_problem(args, _item) = delete_problem(:navigation, "navigation", args["navigation"])
      def delete_global_problem(args, _item) = delete_problem(:globals, "global set", args["global"])

      def rename_problem(kind, noun, args)
        from, to = args.values_at("from", "to")
        return "needs from and to" if from.blank? || to.blank?
        return "from and to are the same #{noun}" if from == to
        return "#{noun} '#{from}' is still in the schema" if Nibble.schema.find(kind, from.to_s)

        "#{noun} '#{to}' isn't in the schema" unless Nibble.schema.find(kind, to.to_s)
      end

      def delete_problem(kind, noun, handle)
        return "only deletes a #{noun}" if handle.blank?

        "#{noun} '#{handle}' is still in the schema" if Nibble.schema.find(kind, handle.to_s)
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

      def move_field_problem(args, _item)
        from, to = ends(args)
        return "needs from and to, each naming a field" if from["field"].blank? || to["field"].blank?
        return "needs a collection, taxonomy or global that exists to move to" unless target_item(to)

        same = Drift.scope_of(from) == Drift.scope_of(to)
        return "moves between the fields of one collection or taxonomy, or between globals" unless same || (from["global"] && to["global"])
        return "from and to are the same field" if same && from["field"] == to["field"]

        column = [ from, to ].find { |side| column?(side) }
        return "#{column['field']} isn't a field that can be moved" if column

        types = Drift.field_types
        into = types.dig(Drift.scope_of(to), to["field"]) or return "#{to['field']} isn't a field of #{label(to)}"
        was = types.dig(Drift.scope_of(from), from["field"]) || Records::SchemaSnapshot.latest&.types.to_h.dig(Drift.scope_of(from), from["field"])
        "#{label(from)}.#{from['field']} is #{was} and #{label(to)}.#{to['field']} is #{into}; a value moves only to a field of its type" if was && was != into
      end

      def remove_field_problem(args, _item)
        return "needs a field" if args["field"].blank?
        return "#{args['field']} isn't a field that can be removed" if column?(args)

        "#{args['field']} is still a field of #{label(args)}" if Drift.field_types.dig(Drift.scope_of(args), args["field"])
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

      def move_between_globals(from, to, overwrite, message, left)
        scope(from).find_each.count do |source|
          target = Records::GlobalSet.find_or_initialize_by(handle: to["global"], locale: source.locale)
          data = source.data.to_h.deep_dup
          into = target.data.to_h.deep_dup
          case shift(data, into, from["field"], to["field"], overwrite)
          when :left then left << source and false
          when :moved
            write(target, into, message) if into != target.data.to_h
            write(source, data, message)
          end
        end
      end

      def shift(source, target, field, into, overwrite)
        return unless source.key?(field)

        value = source[field]
        return :left unless value.nil? || overwrite == true || target[into] == value || target[into].nil? || target[into].try(:empty?)

        source.delete(field)
        target[into] = value unless value.nil?
        :moved
      end

      def write(record, data, message)
        record.new_record? ? record.update!(data:) : record.update_columns(data:, updated_at: Time.current)
        saved(record, message)
      end

      def saved(record, message)
        Revisions.write(record.reload, :import, snapshot: record.snapshot, actor: nil, message:)
        Events.publish("record.saved", record.event_payload.merge("mode" => "import", "changes" => {}))
        true
      end

      def term(taxonomy, locale, title)
        slug = title.parameterize
        Records::Term.find_by(taxonomy:, locale:, slug:) ||
          Lifecycle.call(Records::Term.new(taxonomy:, locale:), :create, { "title" => title, "slug" => slug }, actor: Principal.system, mode: :import).then do |result|
            result.ok? ? result.record : raise(Error, "couldn't create #{taxonomy} term '#{title}': #{result.errors}")
          end
      end

      def scope(args)
        return Records::Entry.where(collection: args["collection"]) if args["collection"]
        return Records::GlobalSet.where(handle: args["global"]) if args["global"]

        Records::Term.where(taxonomy: args["taxonomy"])
      end

      def target_item(args)
        return Nibble.schema.collection(args["collection"]) if args["collection"]
        return Nibble.schema.find(:globals, args["global"].to_s) if args["global"]

        Nibble.schema.taxonomy(args["taxonomy"].to_s)
      end

      def label(args) = args["collection"] || args["global"] || args["taxonomy"]

      def ends(args) = args.values_at("from", "to").map { |side| side.is_a?(Hash) ? side.stringify_keys : {} }

      def column?(args) = !args["global"] && Drift::DRAFT_COLUMNS.include?(args["field"])
    end
  end
end
