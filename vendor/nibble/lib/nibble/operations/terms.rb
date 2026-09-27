module Nibble
  module Operations
    module Terms
      TRANSITIONS = %w[trash restore revert].freeze

      module_function

      def operations
        [
          Operation.new(name: "list_terms", title: "List terms", read_only: true, destructive: false, needs: %w[terms read],
            handler: method(:list), description: "Terms in a taxonomy, alphabetical.",
            input: Operations.schema(Operations.page_input("taxonomy" => { "type" => "string" }, "locale" => { "type" => "string" }), %w[taxonomy])),
          Operation.new(name: "get_term", title: "Read a term", read_only: true, destructive: false, needs: %w[terms read],
            handler: method(:get), description: "One term as you would edit it, with its lock_version.",
            input: Operations.schema({ "id" => { "type" => "integer" } }, %w[id])),
          Operation.new(name: "create_term", title: "Create a term", read_only: false, destructive: false, needs: %w[terms write],
            handler: method(:create), description: "Create a term. Terms have no drafts: it is live as soon as it's saved.",
            input: Operations.schema({ "taxonomy" => { "type" => "string" }, "locale" => { "type" => "string" },
                                       "data" => { "type" => "object" } }, %w[taxonomy data], write: true)),
          Operation.new(name: "update_term", title: "Change a term", read_only: false, destructive: false, needs: %w[terms write],
            handler: method(:update), description: "Change some fields of a term. Terms have no drafts: the change is live at once.",
            input: Operations.schema({ "id" => { "type" => "integer" }, "lock_version" => { "type" => "integer" },
                                       "data" => { "type" => "object" } }, %w[id lock_version data], write: true)),
          Operation.new(name: "transition_term", title: "Trash, restore or revert a term", read_only: false, destructive: true,
            needs: %w[terms write], handler: method(:transition), description: "trash, restore, or revert to a revision (revision_id).",
            input: Operations.schema({ "id" => { "type" => "integer" }, "action" => { "type" => "string", "enum" => TRANSITIONS },
                                       "lock_version" => { "type" => "integer" }, "revision_id" => { "type" => "integer" } },
              %w[id action], write: true))
        ]
      end

      def list(input, caller)
        taxonomy = taxonomy!(input["taxonomy"])
        Operations.require!(caller.principal, "terms.#{taxonomy.handle}.view")
        per_page = input["per_page"] || 20
        scope = Records::Term.kept.where(taxonomy: taxonomy.handle, locale: Operations.locale!(input["locale"])).order(:title)
        page = [ input["page"].to_i, 1 ].max
        { "terms" => scope.offset((page - 1) * per_page).limit(per_page).map { |term| summary(term) },
          "page" => { "current_page" => page, "per_page" => per_page, "total" => scope.count } }
      end

      def get(input, caller)
        term = find!(input["id"])
        Operations.require!(caller.principal, "terms.#{term.taxonomy}.view")
        Editable.term(term, site: caller.site)
      end

      def create(input, caller)
        taxonomy = taxonomy!(input["taxonomy"])
        term = Records::Term.new(taxonomy: taxonomy.handle, blueprint: Array(taxonomy["blueprints"]).first, locale: Operations.locale!(input["locale"]))
        attrs = Editable.incoming(term.blueprint_fields, input["data"], columns: Editable::TERM_COLUMNS)
        written(Operations.lifecycle!(term, :create, attrs, caller), caller, "created")
      end

      def update(input, caller)
        term = find!(input["id"])
        attrs = Editable.incoming(term.blueprint_fields, input["data"], columns: Editable::TERM_COLUMNS).merge("lock_version" => input["lock_version"])
        written(Operations.lifecycle!(term, :save, attrs, caller), caller, "saved")
      end

      def transition(input, caller)
        term = find!(input["id"], trashed: input["action"] == "restore")
        written(Operations.lifecycle!(term, input["action"], input.slice("lock_version", "revision_id").compact, caller), caller, input["action"])
      end

      def written(term, caller, what) = Editable.term(term.reload, site: caller.site).merge("result" => what, "site" => caller.site)

      def summary(term) = { "id" => term.id, "title" => term.title, "slug" => term.slug, "uri" => term.uri }

      def find!(id, trashed: false)
        (trashed ? Records::Term.all : Records::Term.kept).find_by(id:) or Operations.not_found!("term #{id}")
      end

      def taxonomy!(handle)
        Nibble.schema.taxonomy(handle.to_s) or raise Failure.new("not_found", "no taxonomy called #{handle}", status: :not_found,
          hint: "describe_site lists the taxonomies")
      end
    end
  end
end
