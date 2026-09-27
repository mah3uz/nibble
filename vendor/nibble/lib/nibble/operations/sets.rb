module Nibble
  module Operations
    module Sets
      NODE = {
        "type" => "object",
        "properties" => {
          "type" => { "type" => "string", "enum" => %w[entry term url] },
          "id" => { "type" => "integer", "description" => "For entry and term links" },
          "url" => { "type" => "string", "description" => "For url links: https, mailto, tel, or a path like /about" },
          "title" => { "type" => "string", "description" => "Required for url links; defaults to the linked record's title" },
          "children" => { "type" => "array" }
        },
        "required" => %w[type]
      }.freeze
      TREE_SCHEMA = { "type" => "array", "items" => NODE }.freeze

      module_function

      def operations
        [
          Operation.new(name: "get_global", title: "Read a global set", read_only: true, destructive: false, needs: %w[globals read],
            handler: method(:get_global), description: "A global set's values, such as the site name or social links.",
            input: Operations.schema({ "handle" => { "type" => "string" }, "locale" => { "type" => "string" } }, %w[handle])),
          Operation.new(name: "update_global", title: "Change a global set", read_only: false, destructive: false, needs: %w[globals write],
            handler: method(:update_global), description: "Change some values of a global set. Globals have no drafts: the change is live at once.",
            input: Operations.schema({ "handle" => { "type" => "string" }, "locale" => { "type" => "string" },
                                       "lock_version" => { "type" => "integer" }, "data" => { "type" => "object" } },
              %w[handle lock_version data], write: true)),
          Operation.new(name: "get_navigation", title: "Read a navigation menu", read_only: true, destructive: false,
            needs: %w[navigation read], handler: method(:get_navigation), description: "A navigation menu's tree of links.",
            input: Operations.schema({ "handle" => { "type" => "string" }, "locale" => { "type" => "string" } }, %w[handle])),
          Operation.new(name: "update_navigation", title: "Change a navigation menu", read_only: false, destructive: false,
            needs: %w[navigation write], handler: method(:update_navigation),
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
        Editable.global(Operations.lifecycle!(set, :save, attrs, caller).reload).merge("result" => "saved", "site" => caller.site)
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
