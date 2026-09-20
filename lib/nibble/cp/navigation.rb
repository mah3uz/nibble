module Nibble
  module Cp
    module Navigation
      ICONS_PATH = "app/frontend/assets/icons/admin".freeze

      class << self
        def icon?(name) = name.to_s.match?(/\A[a-z0-9-]+\z/) && Rails.root.join(ICONS_PATH, "#{name}.svg").exist?

        def for(user, schema: Nibble.schema)
          [
            section("top", nil, [ item("Dashboard", "/admin", "dashboard") ]),
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

            item(collection["title"], "/admin/collections/#{collection.handle}", collection["icon"] || "collection")
          end
          taxonomies = schema.taxonomies.filter_map do |taxonomy|
            next unless Access.can?(user, "terms.#{taxonomy.handle}.view")

            item(taxonomy["title"], "/admin/taxonomies/#{taxonomy.handle}", taxonomy["icon"] || "taxonomy")
          end
          assets = Access.can?(user, "assets.view") ? [ item("Assets", "/admin/media", "media") ] : []
          collections + taxonomies + assets
        end

        def structure_items(user, schema)
          items = []
          globals = schema.globals.select { |global| Access.can?(user, "globals.#{global.handle}.edit") }
          if globals.any?
            children = globals.map { |global| item(global["title"], "/admin/globals/#{global.handle}/edit", "globals") }
            items << item("Globals", "/admin/globals", "globals", children:)
          end
          menus = schema.navigations.select { |menu| Access.can?(user, "navigation.#{menu.handle}.edit") }
          if menus.any?
            children = menus.map { |menu| item(menu["title"], "/admin/navigation/#{menu.handle}/edit", "navigation") }
            items << item("Navigation", "/admin/navigation", "navigation", children:)
          end
          items
        end

        def users_items(user)
          items = []
          items << item("Users", "/admin/users", "users") if Access.can?(user, "users.manage")
          items << item("Roles", "/admin/roles", "permissions") if Access.can?(user, "roles.manage")
          items << item("API tokens", "/admin/api-tokens", "key") if Access.can?(user, "api_tokens.manage")
          items
        end

        def forms?(user, schema)
          schema.forms.any? { |form| Access.can?(user, "forms.#{form.handle}.view") }
        end

        def tools_items(user, schema)
          items = []
          items << item("Forms", "/admin/forms", "forms") if forms?(user, schema)
          items << item("Blueprints", "/admin/blueprints", "blueprints") if Access.can?(user, "utilities.view")
          items << item("Trash", "/admin/trash", "trash") if Access.can?(user, "trash.view")
          items << item("Redirects", "/admin/redirects", "redirects") if Access.can?(user, "redirects.manage")
          items << item("Webhooks", "/admin/webhooks", "webhooks") if Access.can?(user, Webhooks::MANAGE_ABILITY)
          if Access.can?(user, "utilities.view")
            waiting = Releases.summary
            items << item("Updates", "/admin/updates", "download",
                          badge: (waiting.count if waiting.count.positive?),
                          badge_tone: ("danger" if waiting.security))
            children = Utilities::LIST.map { |utility| item(utility[:title], Utilities.url(utility), utility[:icon]) }
            items << item("Utilities", "/admin/utilities", "utilities", children:)
          end
          items
        end
      end
    end
  end
end
