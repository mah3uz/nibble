module Nibble
  class Schema
    module Rules
      STRING = ->(value) { value.is_a?(String) && value.present? }
      OPTIONAL_STRING = ->(value) { value.nil? || STRING.(value) }
      BOOLEAN = ->(value) { value == true || value == false }
      INTEGER = ->(value) { value.is_a?(Integer) && value >= 0 }
      HASH = ->(value) { value.is_a?(Hash) }
      ARRAY = ->(value) { value.is_a?(Array) }
      STRINGS = ->(value) { value.is_a?(Array) && value.all? { |item| STRING.(item) } }
      ROUTE = ->(value) { value.nil? || (value.is_a?(String) && (value.start_with?("/") || value.start_with?("{"))) }
      STRUCTURE = ->(value) do
        value == false || (value.is_a?(Hash) && (value["max_depth"].nil? || INTEGER.(value["max_depth"])) && [ nil, true, false ].include?(value["root"]))
      end
      WORKFLOW = ->(value) { %w[simple review].include?(value) }
      SORT = ->(value) { value.is_a?(String) && value.match?(/\A[a-z_]+:(asc|desc)\z/) }

      KINDS = {
        "collections" => {
          required: %w[title blueprints],
          keys: {
            "title" => STRING, "route" => ROUTE, "dated" => BOOLEAN, "expires" => BOOLEAN, "structure" => STRUCTURE,
            "taxonomies" => STRINGS, "blueprints" => STRINGS, "template" => STRING, "layout" => STRING,
            "workflow" => WORKFLOW, "requires_slugs" => BOOLEAN, "revisions" => HASH, "sitemap" => HASH, "search" => ->(v) { v == false || STRING.(v) },
            "api" => BOOLEAN, "localizable" => BOOLEAN, "sort" => SORT, "icon" => STRING
          }
        },
        "taxonomies" => {
          required: %w[title blueprints],
          keys: {
            "title" => STRING, "route" => ROUTE, "index_route" => ROUTE, "template" => STRING, "index_template" => STRING,
            "layout" => STRING, "blueprints" => STRINGS, "sort" => SORT, "sitemap" => HASH, "api" => BOOLEAN,
            "localizable" => BOOLEAN, "icon" => STRING
          }
        },
        "globals" => {
          required: %w[title blueprint],
          keys: { "title" => STRING, "blueprint" => HASH, "localizable" => BOOLEAN }
        },
        "navigation" => {
          required: %w[title],
          keys: { "title" => STRING, "max_depth" => INTEGER, "collections" => STRINGS, "taxonomies" => STRINGS }
        },
        "forms" => {
          required: %w[title fields],
          keys: {
            "title" => STRING, "fields" => ARRAY, "store" => BOOLEAN, "spam" => HASH, "notify" => ARRAY, "api" => ARRAY,
            "handler" => STRING, "cp_notify" => BOOLEAN, "success" => HASH, "retention_days" => INTEGER
          }
        },
        "apis" => {
          required: %w[base_url],
          keys: { "base_url" => STRING, "headers" => HASH, "timeout" => INTEGER, "errors" => HASH, "retry" => HASH }
        },
        "blueprints" => {
          required: %w[title tabs],
          keys: { "title" => STRING, "hide" => BOOLEAN, "order" => INTEGER, "template" => STRING, "tabs" => HASH }
        },
        "fieldsets" => {
          required: %w[title fields],
          keys: { "title" => STRING, "fields" => ARRAY }
        },
        "search" => {
          required: %w[indexes],
          keys: { "indexes" => HASH }
        },
        "migrations" => {
          required: %w[operations],
          keys: { "operations" => ARRAY }
        }
      }.freeze

      BLUEPRINT_PARENTS = %w[collections taxonomies].freeze
    end
  end
end
