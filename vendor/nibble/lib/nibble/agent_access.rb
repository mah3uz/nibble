module Nibble
  # The site-wide cap on what connected apps may do, set by an administrator. Off until someone turns it on.
  module AgentAccess
    KEY = "agent_access"
    AREAS = %w[entries terms globals navigation assets workflow forms].freeze
    READ = %w[entries.*.view terms.*.view globals.*.view navigation.*.view assets.view].freeze
    PRESETS = {
      "read" => READ,
      "draft" => READ + %w[entries.*.create entries.*.edit entries.*.edit_own],
      "everything" => %w[entries.* terms.* globals.* navigation.* assets.* workflow.*]
    }.freeze
    COLUMNS = { "read" => "Read", "write" => "Write", "publish" => "Publish", "delete" => "Delete" }.freeze
    Area = Data.define(:key, :title, :group, :columns)
    ENTRY_COLUMNS = { "view" => "read", "create" => "write", "edit" => "write", "edit_own" => "write",
                      "publish" => "publish", "delete" => "delete", "delete_own" => "delete" }.freeze
    TERM_COLUMNS = { "view" => "read", "create" => "write", "edit" => "write", "delete" => "delete" }.freeze
    ASSET_COLUMNS = { "view" => "read", "upload" => "write", "edit" => "write", "delete" => "delete" }.freeze

    module_function

    def settings = Records::Setting.read(KEY, {}).to_h

    def enabled? = settings["enabled"] == true

    def device_sign_in? = enabled? && settings["device_sign_in"] == true

    def update!(enabled: nil, device_sign_in: nil, areas: nil)
      current = settings
      current["enabled"] = enabled unless enabled.nil?
      current["device_sign_in"] = device_sign_in unless device_sign_in.nil?
      if areas
        known = areas(schema: Nibble.schema).index_by(&:key)
        current["areas"] = current["areas"].to_h.merge(areas.to_h.slice(*known.keys).to_h do |key, values|
          [ key, known[key].columns.index_with { |column| values.to_h[column] == true } ]
        end)
      end
      Records::Setting.write(KEY, current)
    end

    def areas(schema: Nibble.schema)
      [
        *schema.collections.map do |item|
          Area.new("entries.#{item.handle}", title(item), "Collections", item["files"].present? ? %w[read] : %w[read write publish delete])
        end,
        *schema.taxonomies.map { |item| Area.new("terms.#{item.handle}", title(item), "Taxonomies", %w[read write delete]) },
        Area.new("globals", "Globals", "Site", %w[read write]),
        Area.new("navigation", "Navigation", "Site", %w[read write]),
        Area.new("assets", "Assets", "Site", %w[read write delete]),
        Area.new("forms", "Form submissions", "Site", %w[read])
      ]
    end

    def value(area, column)
      stored = settings.dig("areas", area, column)
      stored.nil? ? default(area, column) : stored == true
    end

    def default(area, column)
      return area != "forms" if column == "read"

      column == "write" && area.start_with?("entries.")
    end

    def allows?(ability)
      return false unless enabled?

      area, column = locate(ability.to_s)
      area.present? && column.present? && value(area, column)
    end

    def locate(ability)
      kind, handle, action, rest = ability.split(".", 4)
      return [ nil, nil ] if rest

      case kind
      when "entries" then [ "entries.#{handle}", ENTRY_COLUMNS[action] ]
      when "workflow" then handle == "approve" && action ? [ "entries.#{action}", "publish" ] : [ nil, nil ]
      when "terms" then [ "terms.#{handle}", TERM_COLUMNS[action] ]
      when "globals", "navigation" then [ kind, { "view" => "read", "edit" => "write" }[action] ]
      when "assets" then action.nil? ? [ "assets", ASSET_COLUMNS[handle] ] : [ nil, nil ]
      when "forms" then [ "forms", action == "view" ? "read" : nil ]
      else [ nil, nil ]
      end
    end

    def grantable?(pattern) = AREAS.include?(pattern.to_s.split(".").first)

    def abilities_for(area, column)
      kind, handle = area.split(".", 2)
      case kind
      when "entries"
        { "read" => %W[entries.#{handle}.view], "write" => %W[entries.#{handle}.create entries.#{handle}.edit entries.#{handle}.edit_own],
          "publish" => %W[entries.#{handle}.publish workflow.approve.#{handle}],
          "delete" => %W[entries.#{handle}.delete entries.#{handle}.delete_own] }[column]
      when "terms"
        { "read" => %W[terms.#{handle}.view], "write" => %W[terms.#{handle}.create terms.#{handle}.edit],
          "delete" => %W[terms.#{handle}.delete] }[column]
      when "globals", "navigation" then { "read" => %W[#{kind}.*.view], "write" => %W[#{kind}.*.edit] }[column]
      when "assets" then { "read" => %w[assets.view], "write" => %w[assets.upload assets.edit], "delete" => %w[assets.delete] }[column]
      when "forms" then column == "read" ? %w[forms.*.view] : nil
      end.to_a
    end

    def concrete_abilities(area, column, schema: Nibble.schema)
      kind = area.split(".").first
      abilities_for(area, column).flat_map do |ability|
        next [ ability ] unless ability.include?("*")

        handles = { "globals" => schema.globals, "navigation" => schema.navigations, "forms" => schema.forms }.fetch(kind, []).map(&:handle)
        handles.map { |handle| ability.sub("*", handle) }
      end
    end

    def person_can?(user, area, column, schema: Nibble.schema)
      return true if column == "read" && %w[globals navigation].include?(area)

      concrete_abilities(area, column, schema:).any? { |ability| Access.can?(user, ability) }
    end

    def preset(name) = PRESETS.fetch(name.to_s)

    def title(item) = item["title"] || item.handle.humanize
  end
end
