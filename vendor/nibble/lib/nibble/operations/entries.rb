module Nibble
  module Operations
    module Entries
      WRITABLE = %w[title slug published_at unpublish_at parent_id template].freeze
      TRANSITIONS = {
        "publish" => "Make it live now, or at published_at. A draft is published over the live entry.",
        "unpublish" => "Take it off the site.",
        "submit" => "Send it for review, in a collection that asks for review.",
        "approve" => "Approve a submitted entry.", "reject" => "Send a submitted entry back, with a comment.",
        "discard_draft" => "Throw away the unpublished draft of a live entry.",
        "trash" => "Move it to the trash. It can be restored.", "restore" => "Bring it back from the trash.",
        "revert" => "Go back to an earlier revision (revision_id from list_revisions)."
      }.freeze
      REFERENCE = { "id" => { "type" => "integer", "description" => "The entry's id" },
                    "uri" => { "type" => "string", "description" => "Or its address on the site, like /about" } }.freeze

      module_function

      def operations
        [
          Operation.new(name: "list_entries", title: "List entries", read_only: true, destructive: false, needs: %w[entries read],
            handler: method(:list),
            description: "Entries in a collection, drafts included, newest first unless sorted. Use filter to narrow by a field.",
            input: Operations.schema(Operations.page_input(
              "collection" => { "type" => "string" }, "locale" => { "type" => "string" },
              "status" => { "type" => "string", "enum" => %w[published draft scheduled unpublished in_review approved] },
              "filter" => { "type" => "object", "description" => "Field conditions, e.g. {\"slug\": \"hello\"} or {\"title\": {\"prefix\": \"How\"}}. Operators: eq ne in lt lte gt gte null prefix." },
              "sort" => { "type" => "string", "description" => "Comma-separated fields; a leading - sorts descending. Default -updated_at." }
            ), %w[collection])),
          Operation.new(name: "get_entry", title: "Read an entry", read_only: true, destructive: false, needs: %w[entries read],
            handler: method(:get),
            description: "One entry as you would edit it: its draft if it has one, rich text as Markdown, and the lock_version to send with a change.",
            input: Operations.schema(REFERENCE.merge("collection" => { "type" => "string", "description" => "Needed with uri" }))),
          Operation.new(name: "create_entry", title: "Create an entry", read_only: false, destructive: false, needs: %w[entries write],
            handler: method(:create),
            description: "Create an entry as a draft. It isn't published: that is a separate step a person may have to take.",
            input: Operations.schema({ "collection" => { "type" => "string" }, "blueprint" => { "type" => "string" },
                                       "locale" => { "type" => "string" },
                                       "data" => { "type" => "object", "description" => "Field values; describe_schema lists them" } },
              %w[collection data], write: true)),
          Operation.new(name: "update_entry", title: "Change an entry", read_only: false, destructive: false, needs: %w[entries write],
            handler: method(:update),
            description: "Change some fields of an entry. Only the fields you send change. A live entry gets a draft, so nothing goes live until it's published.",
            input: Operations.schema({ "id" => { "type" => "integer" }, "lock_version" => { "type" => "integer", "description" => "From get_entry" },
                                       "data" => { "type" => "object" } }, %w[id lock_version data], write: true)),
          Operation.new(name: "transition_entry", title: "Publish, review or trash an entry", read_only: false, destructive: true,
            needs: %w[entries write], handler: method(:transition),
            description: "Move an entry through its life: #{TRANSITIONS.map { |action, text| "#{action}: #{text}" }.join(' ')}",
            input: Operations.schema({ "id" => { "type" => "integer" }, "action" => { "type" => "string", "enum" => TRANSITIONS.keys },
                                       "lock_version" => { "type" => "integer" }, "published_at" => { "type" => "string" },
                                       "comment" => { "type" => "string" }, "revision_id" => { "type" => "integer" } },
              %w[id action], write: true)),
          Operation.new(name: "list_revisions", title: "List revisions", read_only: true, destructive: false, needs: %w[entries read],
            handler: method(:revisions), description: "An entry's saved versions, newest first, with who made each and through which app.",
            input: Operations.schema({ "id" => { "type" => "integer" } }, %w[id]))
        ]
      end

      def list(input, caller)
        collection = collection!(input["collection"])
        Operations.require!(caller.principal, "entries.#{collection.handle}.view")
        files!(collection)
        per_page = input["per_page"] || 20
        spec = { "from" => "entries:#{collection.handle}", "locale" => Operations.locale!(input["locale"]),
                 "where" => filter(input), "sort" => sorts(input["sort"]), "paginate" => { "per_page" => per_page, "param" => "page" } }
        context = Query::Context.new(locale: spec["locale"], now: Time.current, entry: nil, term: nil, set: nil,
          params: { "page" => input["page"] || 1 }, scope: :preview)
        result = Query.build(spec.compact, context).result
        { "entries" => result.records.map { |record| Editable.entry_summary(record) }, "page" => result.pagination }
      rescue Query::Invalid => error
        raise Failure.new("invalid_input", error.message, hint: "Filter and sort on a collection's fields; describe_schema lists them.")
      end

      def get(input, caller)
        entry = find!(input)
        Operations.require!(caller.principal, "entries.#{entry.collection}.view", entry)
        Editable.entry(entry, site: caller.site)
      end

      def create(input, caller)
        collection = collection!(input["collection"])
        files!(collection)
        blueprint = input["blueprint"].presence || Array(collection["blueprints"]).first
        unless Nibble.schema.blueprints_for(collection).map(&:handle).include?(blueprint)
          raise Failure.new("invalid_input", "#{collection.handle} has no blueprint #{blueprint}", hint: "describe_schema lists its blueprints")
        end

        entry = Records::Entry.new(collection: collection.handle, blueprint:, locale: Operations.locale!(input["locale"]))
        attrs = Editable.incoming(entry.blueprint_fields, input["data"], columns: WRITABLE)
        written(Operations.lifecycle!(entry, :create, attrs, caller), caller, "created")
      end

      def update(input, caller)
        entry = find!(input)
        attrs = Editable.incoming(entry.blueprint_fields, input["data"], columns: WRITABLE).merge("lock_version" => input["lock_version"])
        written(Operations.lifecycle!(entry, :save, attrs, caller), caller, entry.live? ? "saved as a draft" : "saved")
      end

      def transition(input, caller)
        entry = find!(input, trashed: input["action"] == "restore")
        attrs = input.slice("lock_version", "published_at", "comment", "revision_id").compact
        written(Operations.lifecycle!(entry, input["action"], attrs, caller), caller, input["action"])
      end

      def revisions(input, caller)
        entry = find!(input)
        Operations.require!(caller.principal, "entries.#{entry.collection}.view", entry)
        { "revisions" => entry.revisions.reorder(number: :desc).includes(:actor, :grant).limit(50).map do |revision|
          { "id" => revision.id, "number" => revision.number, "kind" => revision.kind, "at" => revision.created_at.utc.iso8601,
            "by" => revision.actor&.name, "via" => revision.grant&.name, "message" => revision.message }.compact
        end }
      end

      def written(entry, caller, what)
        Editable.entry(entry.reload, site: caller.site).merge("result" => what, "site" => caller.site)
      end

      def find!(input, trashed: false)
        scope = trashed ? Records::Entry.all : Records::Entry.kept
        entry = if input["id"]
          scope.find_by(id: input["id"])
        elsif input["uri"] && input["collection"]
          scope.find_by(collection: input["collection"], uri: Uris.normalize(input["uri"]))
        else
          raise Failure.new("invalid_input", "send id, or uri with collection")
        end
        entry or Operations.not_found!("entry like that")
      end

      def collection!(handle)
        Nibble.schema.collection(handle.to_s) or raise Failure.new("not_found", "no collection called #{handle}", status: :not_found,
          hint: "describe_site lists the collections")
      end

      def files!(collection)
        return if collection["files"].blank?

        raise Failure.new("written_in_files", "#{AgentAccess.title(collection)} is written in files, not stored here", status: :conflict,
          hint: "Its entries live in the site's repository under site/content/#{collection['files']}; read and change them there, then deploy.")
      end

      def filter(input)
        conditions = input["filter"].to_h
        conditions = conditions.merge("status" => input["status"]) if input["status"]
        conditions.presence
      end

      def sorts(value)
        value = value.presence || "-updated_at"
        value.to_s.split(",").map(&:strip).map { |key| key.start_with?("-") ? "#{key.delete_prefix('-')}:desc" : "#{key}:asc" }
      end
    end
  end
end
