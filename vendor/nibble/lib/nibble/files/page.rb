module Nibble
  module Files
    # Stands where a record would, answering what a presenter asks and nothing more.
    class Page
      RECORD_TYPE = "Nibble::Files::Page".freeze

      attr_reader :id, :collection, :slug, :slugs, :uri, :path, :digest, :position, :data, :parent_slugs

      def initialize(id:, collection:, slugs:, uri:, path:, digest:, position:, data:, locale:)
        @id = id
        @collection = collection
        @slugs = slugs
        @slug = slugs.last
        @parent_slugs = slugs[0..-2]
        @uri = uri
        @path = path
        @digest = digest
        @position = position
        @data = data
        @locale = locale
      end

      def record_type = RECORD_TYPE
      def uuid = id
      def locale = @locale
      def title = data["title"].to_s
      def blueprint = data["blueprint"] || collection_item&.data&.then { |item| Array(item["blueprints"]).first }
      def collection_item = Nibble.schema.collection(collection)
      def blueprint_item = collection_item && Nibble.schema.blueprint(collection_item, blueprint)
      def blueprint_fields = Blueprint.for(blueprint_item).fields
      def template = data["template"]

      # A file's prose has no field of its own, so it fills the one written as Markdown.
      def values = body_field ? data.merge(body_field => body) : data
      def has_attribute?(name) = name.to_s == "data"

      def body_field = @body_field ||= blueprint_fields.all.find { |_, field| field.type == "markdown" }&.first

      def status = "published"
      def live? = true
      def trashed? = false
      def published_at = @published_at ||= data["published_at"]&.then { |value| Time.zone.parse(value.to_s) }
      def updated_at = nil
      def author_id = nil

      # Read when the page renders or is searched, not when it is indexed, so the index stays metadata.
      def body = Files.body(path)

      def root? = slugs == [ Reader::ROOT_SLUG ]
      def key = [ collection, *slugs ].join("/")
      def parent_key = parent_slugs.any? ? [ collection, *parent_slugs ].join("/") : nil
      def parent = parent_key && Files.index.at_key(parent_key)
    end
  end
end
