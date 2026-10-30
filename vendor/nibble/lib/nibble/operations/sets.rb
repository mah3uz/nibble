module Nibble
  module Operations
    module Sets
      NODE = {
        "type" => "object",
        "properties" => {
          "kind" => { "type" => "string", "enum" => %w[link], "description" => "link when left out. A heading, where the menu allows one, has no link; its children sit under it" },
          "type" => { "type" => "string", "enum" => %w[url entry term global asset], "description" => "What a link points at. Required unless the item is a heading or a kind without a link" },
          "id" => { "type" => "integer", "description" => "For entry, term and asset links" },
          "url" => { "type" => "string", "description" => "For url links: https, mailto, tel, or a path like /about" },
          "ref" => { "type" => "string", "description" => "For global links: global:<set>.<field>, a link field of a global set" },
          "title" => { "type" => "string", "description" => "Required for url links and headings; defaults to the linked record's title" },
          "new_tab" => { "type" => "boolean", "description" => "Open the link in a new tab. Off when left out" },
          "hidden" => { "type" => "boolean", "description" => "Keep the item out of the site without deleting it" },
          "fields" => { "type" => "object", "description" => "The item's own fields" },
          "show_from" => { "type" => "string", "format" => "date-time", "description" => "ISO 8601; the item appears from then" },
          "show_until" => { "type" => "string", "format" => "date-time", "description" => "ISO 8601; the item disappears after then" },
          "children" => { "type" => "array", "items" => { "type" => "object", "description" => "Same shape as this item" } }
        }
      }.freeze
      TREE_SCHEMA = { "type" => "array", "items" => NODE }.freeze

      module_function

      # A menu's tree schema and custom kinds, derived from its own schema: its item fields, kinds and query sources.
      def menu_schema(item, schema: Nibble.schema)
        menu = MenuSchema.new(item, schema:)
        properties = NODE["properties"].merge(
          "kind" => NODE.dig("properties", "kind").merge("enum" => menu.kind_handles),
          "fields" => { "type" => "object", "description" => "The item's fields" }.merge(FieldSchema.object(menu.item_fields))
        )
        properties = properties.merge("query" => query_schema(menu)) if menu.queries.any?
        { "tree" => { "type" => "array", "items" => NODE.merge("properties" => properties) },
          "kinds" => menu.kinds.to_h { |kind| [ kind.handle, kind_schema(kind, menu) ] }.presence }.compact
      end

      def kind_schema(kind, menu)
        { "title" => kind.display, "link" => kind.link, "children" => kind.children,
          "fields" => { "type" => "object", "description" => "The fields of a #{kind.handle} item, in its `fields`: its own and the menu's item fields" }
            .merge(FieldSchema.object(menu.fields_for(kind.handle))) }
      end

      def query_schema(menu)
        { "type" => "object", "description" => "For a query item: lists entries of one collection as its children",
          "properties" => { "collection" => { "type" => "string", "enum" => menu.queries },
                            "parent" => { "type" => "integer", "description" => "Entry id of the collection, in the menu's locale; lists its children" },
                            "term" => { "type" => "object", "properties" => { "taxonomy" => { "type" => "string" }, "id" => { "type" => "integer" } } },
                            "sort" => { "type" => "string", "description" => "A field or column, with :desc to reverse it. The collection's own sort when left out" },
                            "limit" => { "type" => "integer", "minimum" => 1, "maximum" => MenuQuery::LIMIT, "description" => "#{MenuQuery::LIMIT} when left out" } },
          "required" => %w[collection] }
      end

      def operations
        [
          Operation.new(name: "get_global", title: "Read a global set", read_only: true, destructive: false, needs: %w[globals read],
            handler: method(:get_global), description: "A global set's values, such as the site name or social links.",
            input: Operations.schema({ "handle" => { "type" => "string" }, "locale" => { "type" => "string" } }, %w[handle])),
          Operation.new(name: "update_global", title: "Change a global set", read_only: false, destructive: false, needs: %w[globals write],
            handler: method(:update_global), consequential: true, description: "Change some values of a global set. Globals have no drafts: the change is live at once.",
            input: Operations.schema({ "handle" => { "type" => "string" }, "locale" => { "type" => "string" },
                                       "lock_version" => { "type" => "integer" }, "data" => { "type" => "object" } },
              %w[handle lock_version data], write: true)),
          Operation.new(name: "get_navigation", title: "Read a navigation menu", read_only: true, destructive: false,
            needs: %w[navigation read], handler: method(:get_navigation), description: "A navigation menu's tree of items: links, headings and any kinds the menu defines. describe_schema gives the item shape.",
            input: Operations.schema({ "handle" => { "type" => "string" }, "locale" => { "type" => "string" } }, %w[handle])),
          Operation.new(name: "update_navigation", title: "Change a navigation menu", read_only: false, destructive: false,
            needs: %w[navigation write], handler: method(:update_navigation), consequential: true,
            description: "Replace a navigation menu's whole tree. Menus have no drafts: the change is live at once.",
            input: Operations.schema({ "handle" => { "type" => "string" }, "locale" => { "type" => "string" },
                                       "lock_version" => { "type" => "integer" }, "tree" => TREE_SCHEMA },
              %w[handle lock_version tree], write: true))
        ]
      end

      def get_global(input, caller)
        set = global!(input["handle"], input["locale"])
        Operations.require!(caller.principal, "globals.#{set.handle}.view")
        Editable.global(set)
      end

      def update_global(input, caller)
        set = global!(input["handle"], input["locale"])
        attrs = Editable.incoming(set.blueprint_fields, input["data"]).merge("lock_version" => input["lock_version"])
        result = Operations.change!(set, :save, attrs, caller)
        Editable.global(result.record.reload).merge("result" => "saved", "site" => caller.site, **Operations.ignored(result))
      end

      def get_navigation(input, caller)
        tree = navigation!(input["handle"], input["locale"])
        Operations.require!(caller.principal, "navigation.#{tree.handle}.view")
        { "handle" => tree.handle, "locale" => tree.locale, "lock_version" => tree.lock_version, "tree" => tree.tree.to_a }
      end

      def update_navigation(input, caller)
        tree = navigation!(input["handle"], input["locale"])
        saved = Operations.lifecycle!(tree, :save, { "tree" => input["tree"], "lock_version" => input["lock_version"] }, caller).reload
        { "handle" => saved.handle, "locale" => saved.locale, "lock_version" => saved.lock_version, "tree" => saved.tree.to_a,
          "result" => "saved", "site" => caller.site }
      end

      def global!(handle, locale)
        item = handle.to_s != Integrations::HANDLE && Nibble.schema.find(:globals, handle.to_s) or Operations.not_found!("global set #{handle}")
        Records::GlobalSet.find_or_initialize_by(handle: item.handle, locale: Operations.locale!(locale))
      end

      def navigation!(handle, locale)
        item = Nibble.schema.find(:navigation, handle.to_s) or Operations.not_found!("navigation menu #{handle}")
        Records::NavigationTree.find_or_initialize_by(handle: item.handle, locale: Operations.locale!(locale))
      end
    end
  end
end
