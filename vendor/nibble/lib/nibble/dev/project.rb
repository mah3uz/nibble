module Nibble
  module Dev
    module Project
      GENERATORS = %w[blueprint collection fieldset form global navigation plugin taxonomy theme view].freeze

      module_function

      def tools
        [
          Tool.new(name: "project_info", title: "Project info", read_only: true, handler: method(:info), input: Dev.schema,
            description: "Versions, the active theme and where it lives, the schema's fingerprint, files taken over from " \
                         "Nibble (ejected), and any of Nibble's own files changed in place, which the next upgrade refuses."),
          Tool.new(name: "where_is", title: "Find where something lives", read_only: true, handler: method(:where_is),
            description: "Where a Ruby constant, theme view, layout, component, Control Plane page or schema item is defined, " \
                         "whose file it is (nibble or site), and how the site changes it: edit, eject, or override.",
            input: Dev.schema({ "name" => { "type" => "string", "description" => "Nibble::Query, posts/show, SiteHeader, cp/entries/Edit, collections/posts" } }, %w[name])),
          Tool.new(name: "eject", title: "Take over one of Nibble's files", read_only: false, handler: method(:eject),
            description: "Copy a Nibble file the site may change into site/ and record it, so upgrades report when the original moves on.",
            input: Dev.schema({ "path" => { "type" => "string", "description" => "Relative to the site, under vendor/nibble/" } }, %w[path])),
          Tool.new(name: "generate", title: "Generate a stub", read_only: false, handler: method(:generate),
            description: "Write a schema or theme stub into the site's own files, as bin/rails nibble:generate does, and list what it wrote.",
            input: Dev.schema({ "kind" => { "type" => "string", "enum" => GENERATORS }, "name" => { "type" => "string" } }, %w[kind name]))
        ]
      end

      def info(_input)
        schema = Nibble.schema
        theme = Nibble.config.theme_path
        {
          "nibble" => Nibble::VERSION, "rails" => Rails.version, "ruby" => RUBY_VERSION, "environment" => Rails.env,
          "theme" => theme && { "handle" => Nibble.config.theme, "path" => Dev.relative(theme), "owner" => Dev.owner(theme) },
          "schema" => { "fingerprint" => schema.digest.first(12),
                        "counts" => schema.items.group_by(&:kind).transform_values(&:size) },
          "ejected" => Eject.manifest.values.map { |ejection| { "source" => ejection.source, "target" => ejection.target, "original_changed" => Eject.changed_since?(ejection) } },
          "nibble_files_changed_in_place" => Eject.unmanaged,
          "agent_access" => AgentAccess.enabled?,
          "architecture" => "vendor/nibble/NIBBLE-ARCHITECTURE.md"
        }
      end

      def where_is(input)
        name = input["name"].to_s.strip
        found = constant(name) + files(name) + schema_item(name)
        { "name" => name, "found" => found, "hint" => found.empty? ? "Nothing by that name. Try a view path like posts/show or a class like Nibble::Query." : nil }.compact
      end

      def constant(name)
        return [] unless name.match?(/\A[A-Z]\w*(::[A-Z]\w*)*\z/) && name.safe_constantize

        file, line = Object.const_source_location(name)
        file ? [ located("constant", file, line:) ] : []
      end

      def files(name)
        theme_dirs = [ Nibble.config.theme_path, Nibble.core_root.join("themes", Nibble.config.theme.to_s) ].compact.uniq
        candidates = theme_dirs.flat_map do |dir|
          %w[views layouts components views/sets].map { |folder| dir.join(folder, "#{name}.vue") }
        end
        candidates += [ Nibble.core_root.join("frontend/nibble-cp/pages/#{name}.vue"), Nibble.site_root.join("cp/pages/#{name}.vue") ]
        candidates.select(&:file?).uniq.map { |path| located("file", path) }
      end

      def schema_item(name)
        item = Nibble.schema.items.find { |candidate| candidate.key == name } or return []

        [ located("schema", item.path).merge("layer" => item.layer.to_s) ]
      end

      def located(kind, path, line: nil)
        relative = Dev.relative(path)
        owner = Dev.owner(path)
        change = if owner == "site" then "edit it"
        elsif Eject.target_for(relative) then "eject it (#{Eject.target_for(relative)})"
        elsif relative.include?("/core_schema/") then "define the same handle in site/schema/ to override it"
        elsif relative.include?("/themes/") then "start a theme of your own (nibble:generate:theme) and change it there"
        else "don't: it's Nibble's. Use a schema layer, a slot under site/cp/slots, or a setting"
        end
        { "kind" => kind, "path" => relative, "line" => line, "owner" => owner, "change" => change }.compact
      end

      def eject(input)
        ejection = Eject.run(input["path"].to_s)
        { "source" => ejection.source, "target" => ejection.target, "result" => "ejected" }
      rescue Eject::Refused => error
        { "error" => error.message }
      end

      def generate(input)
        kind = input["kind"].to_s
        return { "error" => "kind must be one of #{GENERATORS.join(', ')}" } unless GENERATORS.include?(kind)

        before = changed_files
        output, ok = Dev.run("bin/rails", "nibble:generate:#{kind}", input["name"].to_s, timeout: 120)
        { "ok" => ok, "output" => Dev.clip(output, 4_000), "files" => changed_files - before }
      end

      def changed_files
        output, = Dev.run("git", "status", "--porcelain", "--untracked-files=all", timeout: 30)
        output.lines.map { |line| line[3..].to_s.strip }
      end
    end
  end
end
