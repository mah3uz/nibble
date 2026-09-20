module Nibble
  module Access
    module Catalogue
      class << self
        def groups(schema: Nibble.schema)
          [ collections_group(schema), taxonomies_group(schema), globals_group(schema), navigation_group(schema),
            assets_group, forms_group(schema), users_group, tools_group ].compact
        end

        def abilities(schema: Nibble.schema) = flatten(groups(schema:)).map { |node| node["value"] }

        def unknown(held, schema: Nibble.schema)
          known = abilities(schema:)
          Array(held).reject { |pattern| pattern == "*" || known.any? { |ability| Access.matches?([ pattern ], ability) } }
        end

        def flatten(nodes)
          Array(nodes).flat_map do |node|
            children = node["children"] || node["abilities"]
            (node["value"] ? [ node ] : []) + flatten(children)
          end
        end

        private

        def card(handle, title, abilities) = { "handle" => handle, "title" => title, "abilities" => abilities }

        def node(value, title, description = nil, children: [])
          { "value" => value, "title" => title, "description" => description, "children" => children }
        end

        def collections_group(schema)
          return if schema.collections.none?

          all = node("entries.*", "All collections", "Every permission below, including collections added later.")
          card("collections", "Collections", [ all ] + schema.collections.map { |item| collection_node(item) })
        end

        def collection_node(collection)
          handle = collection.handle
          children = [
            node("entries.#{handle}.create", "Create new entries"),
            node("entries.#{handle}.edit_own", "Edit their own entries", children: [
              node("entries.#{handle}.edit", "Edit anyone's entries", children: [
                node("entries.#{handle}.publish", "Publish and unpublish", "Move an entry between draft, scheduled and published."),
                node("entries.#{handle}.delete", "Delete entries")
              ])
            ])
          ]
          children << node("workflow.approve.#{handle}", "Approve entries for publishing") if collection["workflow"]
          node("entries.#{handle}.view", "View #{title_of(collection)} entries", children:)
        end

        def taxonomies_group(schema)
          return if schema.taxonomies.none?

          all = node("terms.*", "All taxonomies", "Every permission below, including taxonomies added later.")
          card("taxonomies", "Taxonomies", [ all ] + schema.taxonomies.map { |item| taxonomy_node(item) })
        end

        def taxonomy_node(taxonomy)
          handle = taxonomy.handle
          node("terms.#{handle}.view", "View #{title_of(taxonomy)} terms", children: [
            node("terms.#{handle}.create", "Create new terms"),
            node("terms.#{handle}.edit", "Edit terms", children: [ node("terms.#{handle}.delete", "Delete terms") ])
          ])
        end

        def globals_group(schema)
          return if schema.globals.none?

          all = node("globals.*", "All global sets", "Every permission below, including global sets added later.")
          items = schema.globals.map { |item| node("globals.#{item.handle}.edit", "Edit #{title_of(item)} globals") }
          card("globals", "Globals", [ all ] + items)
        end

        def navigation_group(schema)
          return if schema.navigations.none?

          all = node("navigation.*", "All navigations", "Every permission below, including navigations added later.")
          items = schema.navigations.map { |item| node("navigation.#{item.handle}.edit", "Edit #{title_of(item)}") }
          card("navigation", "Navigation", [ all ] + items)
        end

        def assets_group
          card("assets", "Assets", [
            node("assets.*", "All asset permissions", "Every permission below."),
            node("assets.view", "View assets", children: [
              node("assets.upload", "Upload new assets"),
              node("assets.edit", "Edit assets", "Rename, move, replace and edit an asset's fields.",
                children: [ node("assets.delete", "Delete assets") ])
            ])
          ])
        end

        def forms_group(schema)
          return if schema.forms.none?

          all = node("forms.*", "All forms", "Every permission below, including forms added later.")
          card("forms", "Forms", [ all ] + schema.forms.map { |item| form_node(item) })
        end

        def form_node(form)
          handle = form.handle
          node("forms.#{handle}.view", "View #{title_of(form)} submissions", children: [
            node("forms.#{handle}.export", "Export submissions", "Download the submissions as CSV."),
            node("forms.#{handle}.edit", "Retry deliveries"),
            node("forms.#{handle}.delete", "Delete submissions")
          ])
        end

        def users_group
          card("users", "Users", [
            node("users.manage", "Manage users", "Invite, edit and remove control panel users, and set their roles."),
            node("roles.manage", "Manage roles", "Create roles and change what they grant. Grant this one wisely."),
            node("api_tokens.manage", "Manage API tokens", "Create and revoke tokens for the content API.")
          ])
        end

        def tools_group
          card("tools", "Tools", [
            node("redirects.manage", "Manage redirects", "Edit redirects and the 404 monitor."),
            node("webhooks.manage", "Manage webhooks", "Create webhooks and see their deliveries."),
            node("trash.view", "View the trash", "Restoring and deleting still need the record's own permission."),
            node("utilities.view", "View utilities", children: [
              node("search.rebuild", "Rebuild search indexes"),
              node("content.export", "Export content", "Download every entry, term, global and redirect, drafts included."),
              node("content.import", "Import content", "Create or update content across the site from a package.")
            ])
          ])
        end

        def title_of(item) = item["title"] || item.handle.humanize
      end
    end
  end
end
