module Nibble
  module Cp
    module Navigation
      ICONS_PATH = "vendor/nibble/frontend/nibble-cp/assets/icons/cp".freeze

      class << self
        def icon?(name) = name.to_s.match?(/\A[a-z0-9-]+\z/) && Rails.root.join(ICONS_PATH, "#{name}.svg").exist?

        def for(user, schema: Nibble.schema)
          [
            section("top", nil, [ item("Dashboard", "/cp", "dashboard") ]),
            section("content", "Content", content_items(user, schema)),
            section("structure", "Structure", structure_items(user, schema)),
            section("tools", "Tools", tools_items(user, schema)),
            section("users", "Users", users_items(user))
          ].compact
        end

        private

        def item(title, url, icon, children: nil, active: url, badge: nil, badge_tone: nil)
          { "title" => title, "url" => url, "icon" => icon, "active" => active, "children" => children,
            "badge" => badge, "badge_tone" => badge_tone }
        end

        def section(handle, label, items) = items.any? ? { "handle" => handle, "label" => label, "items" => items } : nil

        def content_items(user, schema)
          collections = schema.collections.filter_map do |collection|
            next unless Access.can?(user, "entries.#{collection.handle}.view")

            item(collection["title"], "/cp/collections/#{collection.handle}", collection["icon"] || "collection")
          end
          taxonomies = schema.taxonomies.filter_map do |taxonomy|
            next unless Access.can?(user, "terms.#{taxonomy.handle}.view")

            item(taxonomy["title"], "/cp/taxonomies/#{taxonomy.handle}", taxonomy["icon"] || "taxonomy")
          end
          assets = Access.can?(user, "assets.view") ? [ item("Assets", "/cp/media", "media") ] : []
          collections + taxonomies + assets
        end

        def structure_items(user, schema)
          items = []
          globals = schema.globals.select { |global| Access.can?(user, "globals.#{global.handle}.edit") }
          if globals.any?
            children = globals.map { |global| item(global["title"], "/cp/globals/#{global.handle}/edit", "globals") }
            items << item("Globals", "/cp/globals", "globals", children:)
          end
          menus = schema.navigations.select { |menu| Access.can?(user, "navigation.#{menu.handle}.edit") }
          if menus.any?
            children = menus.map { |menu| item(menu["title"], "/cp/navigation/#{menu.handle}/edit", "navigation") }
            items << item("Navigation", "/cp/navigation", "navigation", children:)
          end
          items
        end

        def users_items(user)
          items = []
          items << item("Users", "/cp/users", "users") if Access.can?(user, "users.manage")
          items << item("Roles", "/cp/roles", "permissions") if Access.can?(user, "roles.manage")
          items << item("API tokens", "/cp/api-tokens", "key") if Access.can?(user, "api_tokens.manage")
          items
        end

        def forms?(user, schema)
          schema.forms.any? { |form| Access.can?(user, "forms.#{form.handle}.view") }
        end

        def tools_items(user, schema)
          items = []
          items << item("Forms", "/cp/forms", "forms") if forms?(user, schema)
          items << item("Blueprints", "/cp/blueprints", "blueprints") if Access.can?(user, "utilities.view")
          items << item("Trash", "/cp/trash", "trash") if Access.can?(user, "trash.view")
          if Access.can?(user, "redirects.manage")
            children = [ item("Missing pages", "/cp/404s", "magnifying-glass") ]
            items << item("Redirects", "/cp/redirects", "redirects", children:)
          end
          items << item("Webhooks", "/cp/webhooks", "webhooks") if Access.can?(user, Webhooks::MANAGE_ABILITY)
          if Access.can?(user, "utilities.view")
            waiting = Releases.summary
            items << item("Updates", "/cp/updates", "download",
                          badge: (waiting.count if waiting.count.positive?),
                          badge_tone: ("danger" if waiting.security))
            children = Utilities::LIST.map { |utility| item(utility[:title], Utilities.url(utility), utility[:icon]) }
            items << item("Utilities", "/cp/utilities", "utilities", children:)
          end
          items
        end
      end
    end
  end
end
