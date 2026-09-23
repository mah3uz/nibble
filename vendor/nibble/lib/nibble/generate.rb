module Nibble
  module Generate
    class Refused < Error; end

    HANDLE = /\A[a-z][a-z0-9_]*\z/
    Written = Data.define(:path, :note)

    class << self
      def collection(handle, root: Rails.root)
        check!(handle)
        write_all(root,
          "site/schema/collections/#{handle}.yml" => {
            "title" => handle.humanize,
            "route" => "/#{handle.dasherize}/{slug}",
            "blueprints" => [ handle.singularize ],
            "sort" => "published_at:desc",
            "dated" => true
          },
          "site/schema/blueprints/collections/#{handle}/#{handle.singularize}.yml" => blueprint_body(handle.singularize.humanize))
      end

      def taxonomy(handle, root: Rails.root)
        check!(handle)
        write_all(root,
          "site/schema/taxonomies/#{handle}.yml" => {
            "title" => handle.humanize,
            "route" => "/#{handle.dasherize}/{slug}",
            "index_route" => "/#{handle.dasherize}",
            "blueprints" => [ handle.singularize ]
          },
          "site/schema/blueprints/taxonomies/#{handle}/#{handle.singularize}.yml" => blueprint_body(handle.singularize.humanize))
      end

      def blueprint(path, root: Rails.root)
        parent, handle = path.to_s.split("/", 2)
        raise Refused, "blueprints are named <collection>/<handle>, e.g. posts/guide" if handle.blank?

        check!(handle)
        kind = root.join("site/schema/taxonomies/#{parent}.yml").file? || Nibble.schema.taxonomy(parent) ? "taxonomies" : "collections"
        write_all(root, "site/schema/blueprints/#{kind}/#{parent}/#{handle}.yml" => blueprint_body(handle.humanize))
      end

      def fieldset(handle, root: Rails.root)
        check!(handle)
        write_all(root, "site/schema/fieldsets/#{handle}.yml" => { "title" => handle.humanize, "fields" => [ text_field ] })
      end

      def global(handle, root: Rails.root)
        check!(handle)
        write_all(root, "site/schema/globals/#{handle}.yml" => {
          "title" => handle.humanize,
          "blueprint" => { "tabs" => { "main" => { "sections" => [ { "fields" => [ text_field ] } ] } } }
        })
      end

      def navigation(handle, root: Rails.root)
        check!(handle)
        write_all(root, "site/schema/navigation/#{handle}.yml" => { "title" => handle.humanize, "max_depth" => 2 })
      end

      def form(handle, root: Rails.root)
        check!(handle)
        write_all(root, "site/schema/forms/#{handle}.yml" => {
          "title" => handle.humanize,
          "store" => true,
          "fields" => [
            { "handle" => "name", "field" => { "type" => "text", "display" => "Name", "validate" => [ "required" ] } },
            { "handle" => "email", "field" => { "type" => "text", "display" => "Email", "validate" => [ "required", "email" ] } },
            { "handle" => "message", "field" => { "type" => "textarea", "display" => "Message", "validate" => [ "required" ] } }
          ]
        })
      end

      def theme(handle, root: Rails.root)
        check!(handle)
        source = root.join("vendor/nibble/themes", DEFAULT_THEME)
        target = root.join("site/themes", handle)
        raise Refused, "site/themes/#{handle} already exists" if target.exist?
        raise Refused, "there is no vendor/nibble/themes/#{DEFAULT_THEME} to copy" unless source.directory?

        target.dirname.mkpath
        FileUtils.cp_r(source, target)
        target.join("theme.yml").write(theme_manifest(handle).to_yaml)
        rename_package(target.join("package.json"), handle)

        [ Written.new(path: "site/themes/#{handle}", note: activate(handle, root)) ]
      end

      VIEW_NAME = %r{\A[a-z][a-z0-9_]*(/[a-z][a-z0-9_]*)*\z}

      def view(name, collection: nil, root: Rails.root, schema: Nibble.schema, theme: Nibble.config.theme)
        raise Refused, "'#{name}' must be lowercase names separated by /" unless name.to_s.match?(VIEW_NAME)
        raise Refused, "there is no theme to write into; generate one first" if theme.blank?
        raise Refused, "vendor/nibble/themes/#{theme} is Nibble's — run nibble:generate:theme first" if theme == DEFAULT_THEME

        item = collection && (schema.collections.find { |one| one.handle == collection } or
          raise Refused, "there is no #{collection} collection")
        written = write_all(root,
          "site/themes/#{theme}/views/#{name}.yml" => view_query(item),
          "site/themes/#{theme}/views/#{name}.vue" => view_body(name, item, schema))

        [ *written[..-2], Written.new(path: written.last.path, note: wiring(name, item)) ]
      end

      def plugin(_handle, root: Rails.root)
        raise Refused, "there is no extension API yet, so there is nothing for a plugin to plug into"
      end

      private

      def check!(handle)
        raise Refused, "'#{handle}' must be lowercase letters, numbers and underscores" unless handle.to_s.match?(HANDLE)
      end

      def theme_manifest(handle)
        { "name" => handle.humanize, "handle" => handle, "version" => "0.1.0", "nibble" => "^#{THEME_API_VERSION}",
          "description" => "#{handle.humanize}, a theme for Nibble." }
      end

      def rename_package(path, handle)
        return unless path.file?

        package = JSON.parse(path.read)
        package["name"] = "@nibble-theme/#{handle}"
        path.write("#{JSON.pretty_generate(package)}\n")
      end

      # The site's file: only the line naming the theme is touched.
      def activate(handle, root)
        settings = root.join("config/nibble.yml")
        return "set NIBBLE_THEME=#{handle}, or theme: #{handle} in config/nibble.yml, to use it" unless settings.file?

        body = settings.read
        return "add theme: #{handle} to config/nibble.yml to use it" unless body.match?(/^(\s*)theme:\s*\S+/)

        settings.write(body.sub(/^(\s*)theme:\s*\S+/) { "#{Regexp.last_match(1)}theme: #{handle}" })
        "config/nibble.yml now names it as this site's theme"
      end

      def view_query(item)
        return { "related" => { "from" => "entries:#{item.handle}", "limit" => 3 } } if item.nil?

        { "params" => [ "page" ],
          "items" => { "from" => "entries:#{item.handle}", "paginate" => { "per_page" => 12 } } }
      end

      def view_body(name, item, schema)
        depth = "../" * (name.count("/") + 1)
        record = item ? record_type(item, schema) : "RecordBase"
        <<~VUE
          <script setup lang="ts">
          import type { ViewProps, #{record} } from '#{depth}.nibble/types'

          defineProps<ViewProps['#{name}'] & { page: #{record} }>()
          </script>

          <template>
            <article>
              <h1>{{ page.title }}</h1>
            </article>
          </template>
        VUE
      end

      def wiring(name, item)
        return "set template: #{name} on a collection or blueprint to use it" if item.nil?

        "add template: #{name} to site/schema/collections/#{item.handle}.yml to use it"
      end

      def record_type(item, schema)
        blueprint = schema.blueprints_for(item).first or return "RecordBase"

        "#{pascal(item.handle)}#{pascal(blueprint.handle)}"
      end

      def pascal(handle) = handle.to_s.camelize

      def text_field = { "handle" => "body", "field" => { "type" => "textarea", "display" => "Body" } }

      def blueprint_body(title)
        { "title" => title, "tabs" => { "main" => { "sections" => [ { "fields" => [ text_field ] } ] } } }
      end

      # Every target is checked before any is written, so a refusal never leaves half a collection behind.
      def write_all(root, files)
        files.each_key { |relative| raise Refused, "#{relative} already exists" if root.join(relative).exist? }
        files.map do |relative, data|
          path = root.join(relative)
          path.dirname.mkpath
          path.write(data.is_a?(String) ? data : data.to_yaml)
          Written.new(path: relative, note: nil)
        end
      end
    end
  end
end
