module Nibble
  module Operations
    module Site
      KINDS = %w[collection taxonomy global navigation].freeze

      module_function

      def operations
        [
          Operation.new(name: "whoami", title: "Who am I", read_only: true, destructive: false, needs: nil, handler: method(:whoami),
            description: "The person this connection acts as, the site, and what this connection may do in each area. Call it first.",
            input: Operations.schema({})),
          Operation.new(name: "describe_site", title: "Describe the site", read_only: true, destructive: false, needs: nil,
            handler: method(:describe_site), input: Operations.schema({}),
            description: "The site's content model: its collections, taxonomies, global sets, navigation menus and locales, with handles to pass to other operations."),
          Operation.new(name: "get_guide", title: "Read the site guide", read_only: true, destructive: false, needs: nil,
            handler: method(:guide), input: Operations.schema({}),
            description: "How to work on this site: its rules for agents, its content model and its own editorial notes, as Markdown. Its fingerprint changes when the schema or notes change."),
          Operation.new(name: "describe_schema", title: "Describe fields", read_only: true, destructive: false, needs: nil,
            handler: method(:describe_schema),
            description: "The fields of a collection, taxonomy, global set or navigation menu, with the JSON Schema each value is written against. Read it before creating or changing content.",
            input: Operations.schema({ "kind" => { "type" => "string", "enum" => KINDS }, "handle" => { "type" => "string" } }, %w[kind handle])),
          Operation.new(name: "get_approval", title: "Check an approval", read_only: true, destructive: false, needs: nil,
            handler: method(:approval),
            description: "How a request that waited for its person went: pending, approved, done with its result, failed with its error, denied or expired.",
            input: Operations.schema({ "approval" => { "type" => "string", "description" => "The approval id from an approval_required answer." } }, %w[approval]))
        ]
      end

      def whoami(_input, caller)
        principal = caller.principal
        grant = principal.grant
        {
          "site" => { "name" => Nibble::Oauth.site_name, "url" => caller.site },
          "person" => { "name" => principal.user.name, "email" => principal.user.email_address },
          "connection" => grant && { "name" => grant.name, "access" => grant.preset, "expires_at" => grant.expires_at.utc.iso8601 },
          "can" => AgentAccess.areas.to_h do |area|
            columns = area.columns.select { |column| AgentAccess.concrete_abilities(area.key, column).any? { |ability| Policy.can?(principal, ability) } }
            [ area.key, files?(area.key) ? [] : columns ]
          end.reject { |_, columns| columns.empty? }
        }
      end

      def approval(input, caller)
        approval = caller.principal.grant&.approvals&.find_by(public_id: input["approval"])
        approval&.summary or raise Failure.new("not_found", "this connection has no approval #{input['approval']}", status: :not_found)
      end

      def guide(_input, caller) = AgentGuide.document(site: Nibble::Oauth.site_name, url: caller.site)

      def files?(area) = area.start_with?("entries.") && Nibble.schema.collection(area.delete_prefix("entries."))&.[]("files").present?

      def describe_site(_input, caller)
        schema = Nibble.schema
        principal = caller.principal
        {
          "locales" => Nibble.config.locales.map { |locale| { "code" => locale.code, "default" => locale.default } },
          "collections" => schema.collections.select { |item| Policy.can?(principal, "entries.#{item.handle}.view") }.map do |item|
            { "handle" => item.handle, "title" => AgentAccess.title(item), "blueprints" => schema.blueprints_for(item).map(&:handle),
              "dated" => item["dated"] == true, "structured" => item["structure"].is_a?(Hash), "review" => item["workflow"].present?,
              "written_in_files" => item["files"].present?, "route" => item["route"] }.compact
          end,
          "taxonomies" => schema.taxonomies.select { |item| Policy.can?(principal, "terms.#{item.handle}.view") }
            .map { |item| { "handle" => item.handle, "title" => AgentAccess.title(item) } },
          "globals" => sets(schema.globals, "globals", principal),
          "navigation" => sets(schema.navigations, "navigation", principal).map { |set| set.merge(Sets.menu_schema(schema.find(:navigation, set["handle"]), schema:)) }
        }
      end

      def sets(items, kind, principal)
        items.reject { |item| item.handle == Nibble::Integrations::HANDLE }
          .select { |item| Policy.can?(principal, "#{kind}.#{item.handle}.view") }
          .map { |item| { "handle" => item.handle, "title" => AgentAccess.title(item) } }
      end

      def describe_schema(input, caller)
        schema = Nibble.schema
        handle = input["handle"]
        case input["kind"]
        when "collection"
          item = schema.collection(handle) or Operations.not_found!("collection #{handle}")
          Operations.require!(caller.principal, "entries.#{handle}.view")
          { "collection" => handle, "blueprints" => blueprints(schema, item), "columns" => entry_columns }
        when "taxonomy"
          item = schema.taxonomy(handle) or Operations.not_found!("taxonomy #{handle}")
          Operations.require!(caller.principal, "terms.#{handle}.view")
          { "taxonomy" => handle, "blueprints" => blueprints(schema, item) }
        when "global"
          item = handle != Nibble::Integrations::HANDLE && schema.find(:globals, handle) or Operations.not_found!("global set #{handle}")
          Operations.require!(caller.principal, "globals.#{handle}.view")
          { "global" => handle, "fields" => fields(Records::GlobalSet.new(handle: item.handle).blueprint_fields) }
        when "navigation"
          item = schema.find(:navigation, handle) or Operations.not_found!("navigation menu #{handle}")
          Operations.require!(caller.principal, "navigation.#{handle}.view")
          { "navigation" => handle, **Sets.menu_schema(item, schema:) }
        end
      end

      def blueprints(schema, item)
        schema.blueprints_for(item).map do |blueprint|
          { "handle" => blueprint.handle, "title" => blueprint["title"], "fields" => fields(Blueprint.for(blueprint, schema:).fields) }
        end
      end

      def fields(fields)
        fields.all.values.filter_map do |field|
          json = FieldSchema.for(field) or next
          { "handle" => field.handle, "type" => field.type, "display" => field.display, "required" => field.required?,
            "instructions" => field.instructions, "schema" => json }.compact
        end
      end

      def entry_columns
        { "slug" => { "type" => "string" }, "published_at" => { "type" => "string", "description" => "ISO 8601; used when it's published" },
          "unpublish_at" => { "type" => "string" }, "parent_id" => { "type" => "integer", "description" => "For structured collections" },
          "template" => { "type" => "string" } }
      end
    end
  end
end
