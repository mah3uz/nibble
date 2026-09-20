module Nibble
  module ContentMigrations
    module Operations
      NAMES = %w[rename_field change_blueprint set_default move_to_taxonomy].freeze
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
        item = target_item(args) or raise Error, "#{where}: needs a collection or taxonomy that exists"
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
