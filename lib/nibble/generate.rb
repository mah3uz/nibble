module Nibble
  module Generate
    class Refused < Error; end

    HANDLE = /\A[a-z][a-z0-9_]*\z/
    Written = Data.define(:path, :note)

    class << self
      def collection(handle, root: Rails.root)
        check!(handle)
        write_all(root,
          "schema/collections/#{handle}.yml" => {
            "title" => handle.humanize,
            "route" => "/#{handle.dasherize}/{slug}",
            "blueprints" => [ handle.singularize ],
            "sort" => "published_at:desc",
            "dated" => true
          },
          "schema/blueprints/collections/#{handle}/#{handle.singularize}.yml" => blueprint_body(handle.singularize.humanize))
      end

      def taxonomy(handle, root: Rails.root)
        check!(handle)
        write_all(root,
          "schema/taxonomies/#{handle}.yml" => {
            "title" => handle.humanize,
            "route" => "/#{handle.dasherize}/{slug}",
            "index_route" => "/#{handle.dasherize}",
            "blueprints" => [ handle.singularize ]
          },
          "schema/blueprints/taxonomies/#{handle}/#{handle.singularize}.yml" => blueprint_body(handle.singularize.humanize))
      end

      def blueprint(path, root: Rails.root)
        parent, handle = path.to_s.split("/", 2)
        raise Refused, "blueprints are named <collection>/<handle>, e.g. posts/guide" if handle.blank?

        check!(handle)
        kind = root.join("schema/taxonomies/#{parent}.yml").file? || Nibble.schema.taxonomy(parent) ? "taxonomies" : "collections"
        write_all(root, "schema/blueprints/#{kind}/#{parent}/#{handle}.yml" => blueprint_body(handle.humanize))
      end

      def fieldset(handle, root: Rails.root)
        check!(handle)
        write_all(root, "schema/fieldsets/#{handle}.yml" => { "title" => handle.humanize, "fields" => [ text_field ] })
      end

      def global(handle, root: Rails.root)
        check!(handle)
        write_all(root, "schema/globals/#{handle}.yml" => {
          "title" => handle.humanize,
          "blueprint" => { "tabs" => { "main" => { "sections" => [ { "fields" => [ text_field ] } ] } } }
        })
      end

      def navigation(handle, root: Rails.root)
        check!(handle)
        write_all(root, "schema/navigation/#{handle}.yml" => { "title" => handle.humanize, "max_depth" => 2 })
      end

      def form(handle, root: Rails.root)
        check!(handle)
        write_all(root, "schema/forms/#{handle}.yml" => {
          "title" => handle.humanize,
          "store" => true,
          "fields" => [
            { "handle" => "name", "field" => { "type" => "text", "display" => "Name", "validate" => [ "required" ] } },
            { "handle" => "email", "field" => { "type" => "text", "display" => "Email", "validate" => [ "required", "email" ] } },
            { "handle" => "message", "field" => { "type" => "textarea", "display" => "Message", "validate" => [ "required" ] } }
          ]
        })
      end

      def plugin(_handle, root: Rails.root)
        raise Refused, "there is no extension API yet, so there is nothing for a plugin to plug into"
      end

      private

      def check!(handle)
        raise Refused, "'#{handle}' must be lowercase letters, numbers and underscores" unless handle.to_s.match?(HANDLE)
      end

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
          path.write(data.to_yaml)
          Written.new(path: relative, note: nil)
        end
      end
    end
  end
end
