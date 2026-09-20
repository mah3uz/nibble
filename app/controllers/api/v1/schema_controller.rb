module Api
  module V1
    class SchemaController < BaseController
      before_action :readable!

      def show
        schema = Nibble.schema
        respond({ "data" => {
          "collections" => schema.collections.select { |item| item["api"] }.map { |item| item_props(item, schema) },
          "taxonomies" => schema.taxonomies.select { |item| item["api"] }.map { |item| item_props(item, schema) },
          "globals" => schema.globals.reject { |item| item.handle == Nibble::Integrations::HANDLE }
            .map { |item| { "handle" => item.handle, "title" => item["title"] } },
          "navigation" => schema.navigations.map { |item| { "handle" => item.handle, "title" => item["title"] } },
          "locales" => Nibble.config.locales.map { |locale| { "code" => locale.code, "default" => locale.default } }
        } })
      end

      private

      def item_props(item, schema)
        { "handle" => item.handle, "title" => item["title"],
          "blueprints" => schema.blueprints_for(item).map { |blueprint| blueprint_props(blueprint, schema) } }
      end

      def blueprint_props(item, schema)
        fields = Nibble::Blueprint.new(item, schema:).fields.all.values
        { "handle" => item.handle, "title" => item["title"],
          "fields" => fields.map { |field| { "handle" => field.handle, "type" => field.type, "display" => field.display } } }
      end
    end
  end
end
